#!/bin/bash
# =====================================================================
#  monitor.sh - 앱이 살아 있는지 확인하고, CPU/MEM/DISK 를 기록한다
#
#  설치 위치 : $AGENT_HOME/bin/monitor.sh  (agent-dev:agent-core, 750)
#  실행하는 쪽: agent-admin 의 crontab (1분마다)
#
#  순서
#   1. 프로세스 확인  -> 없으면 exit 1   (치명적: 바로 종료)
#   2. 포트 확인      -> 안 열렸으면 exit 1
#   3. 방화벽 확인    -> 꺼져 있으면 [WARNING] 만 출력 (계속 진행)
#   4. CPU/MEM/DISK 수집
#   5. 임계값 넘으면  -> [WARNING] 만 출력 (계속 진행)
#   6. monitor.log 에 한 줄 추가 (>>)
# =====================================================================

# ---------- 설정값 ----------
# cron 은 ~/.bashrc 를 읽지 않아 환경변수가 비어 있을 수 있다 -> 기본값을 둔다
APP_NAME="agent-app-linux"                    # 제공 앱 파일 이름 (x86, arm64 둘 다 이 이름으로 시작)
APP_PORT="${AGENT_PORT:-15034}"
LOG_DIR="${AGENT_LOG_DIR:-/var/log/agent-app}"
LOG_FILE="$LOG_DIR/monitor.log"

CPU_LIMIT=20    # %
MEM_LIMIT=10    # %
DISK_LIMIT=80   # %

# 소수끼리 비교 (bash 의 [ ] 는 정수만 비교할 수 있어서 awk 사용)
# 사용법: is_over 25.3 20  -> 25.3 > 20 이면 참
is_over() {
    awk -v value="$1" -v limit="$2" 'BEGIN { exit !(value > limit) }'
}

echo "====== SYSTEM MONITOR RESULT ======"
echo
echo "[HEALTH CHECK]"

# ---------- 1. 프로세스 확인 ----------
# pgrep -f : 실행 명령줄(예: ./agent-app-linux-x86)에서 찾는다
#   패턴 '^[^ ]*agent-app-linux' = 명령줄의 "첫 단어"(실제로 실행된 프로그램)가 앱인 것만
#   -> 'vim agent-app-linux-x86', 'bash -c "./agent-app-linux-x86"' 처럼
#      명령줄 중간에 이름만 들어 있는 다른 프로세스는 걸리지 않는다
# pgrep -o : 여러 개면 가장 먼저 뜬 것 하나의 PID
#   (제공 앱은 PyInstaller 실행 파일이라 프로세스가 2개 뜬다: 부모가 압축을 풀고 자식이 실제로 일함)
PID=$(pgrep -o -f "^[^ ]*${APP_NAME}")
if [ -z "$PID" ]; then
    echo "Checking process '$APP_NAME'... [FAIL] not running"
    exit 1
fi
echo "Checking process '$APP_NAME'... [OK] (PID: $PID)"

# ---------- 2. 포트 확인 ----------
# ss -ltn : LISTEN 중인(l) TCP(t) 소켓을 숫자로(n) 보여준다
# 4번째 칸(Local Address:Port)이 ":15034" 로 끝나는 줄이 있으면 열린 것
if ! ss -ltn | awk '{ print $4 }' | grep -q ":${APP_PORT}$"; then
    echo "Checking port $APP_PORT... [FAIL] not listening"
    exit 1
fi
echo "Checking port $APP_PORT... [OK]"

# ---------- 3. 방화벽 확인 (경고만) ----------
# 'ufw status' 는 root 만 실행할 수 있어서 sudo 로 실행한다.
# /etc/sudoers.d/agent-monitor 에서 agent-core 그룹에게 "ufw status" 한 가지만 허용해 두었다.
#   sudo -n : 비밀번호를 묻지 않는다 (cron 에는 입력할 사람이 없음. 허용 안 됐으면 바로 실패 -> 경고)
# 설정 파일(/etc/ufw/ufw.conf)의 ENABLED=yes 는 "켜기로 설정됨"일 뿐이라,
# 규칙이 실제로 올라가 있는지는 ufw status 로 봐야 정확하다.
if sudo -n /usr/sbin/ufw status 2>/dev/null | grep -q "^Status: active"; then
    echo "Checking firewall (ufw)... [OK] active"
else
    echo "[WARNING] Firewall (ufw) is not active"
fi

echo
echo "[RESOURCE MONITORING]"

# ---------- 4. 자원 수집 ----------
# CPU: /proc/stat 의 'cpu' 줄 = 부팅 후 CPU 가 각 일에 쓴 시간의 누적 합계
#      칸 순서: user nice system idle iowait irq softirq steal
#      1초 간격으로 두 번 읽고, 그 1초 동안 '쉬지 않은 시간' 비율을 구한다
read_cpu() {
    awk '/^cpu / { idle = $5 + $6; total = 0; for (i = 2; i <= 9; i++) total += $i; print idle, total }' /proc/stat
}
read -r IDLE1 TOTAL1 <<< "$(read_cpu)"
sleep 1
read -r IDLE2 TOTAL2 <<< "$(read_cpu)"
CPU=$(awk -v idle=$((IDLE2 - IDLE1)) -v total=$((TOTAL2 - TOTAL1)) \
    'BEGIN { printf "%.1f", (total - idle) * 100 / total }')

# MEM: free 의 Mem 줄에서 used / total * 100
MEM=$(free | awk '/^Mem:/ { printf "%.1f", $3 * 100 / $2 }')

# DISK: 루트(/) 파티션의 Use% 칸에서 % 기호를 뺀 숫자
DISK=$(df -P / | awk 'NR == 2 { gsub("%", "", $5); print $5 }')

echo "CPU Usage : ${CPU}%"
echo "MEM Usage : ${MEM}%"
echo "DISK Used : ${DISK}%"
echo

# ---------- 5. 임계값 확인 (경고만) ----------
is_over "$CPU"  "$CPU_LIMIT"  && echo "[WARNING] CPU threshold exceeded (${CPU}% > ${CPU_LIMIT}%)"
is_over "$MEM"  "$MEM_LIMIT"  && echo "[WARNING] MEM threshold exceeded (${MEM}% > ${MEM_LIMIT}%)"
is_over "$DISK" "$DISK_LIMIT" && echo "[WARNING] DISK threshold exceeded (${DISK}% > ${DISK_LIMIT}%)"

# ---------- 6. 로그 기록 ----------
# >> : 파일 끝에 이어 붙이기 (> 를 쓰면 매번 기존 기록이 지워진다)
NOW=$(date '+%Y-%m-%d %H:%M:%S')
if ! echo "[$NOW] PID:$PID CPU:${CPU}% MEM:${MEM}% DISK_USED:${DISK}%" >> "$LOG_FILE"; then
    echo "[ERROR] Cannot write log: $LOG_FILE"
    exit 1
fi
echo "[INFO] Log appended: $LOG_FILE"
exit 0
