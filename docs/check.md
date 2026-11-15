# 평가 확인 가이드: 하나씩 실행해서 확인하기

평가표 질문마다 **VM에서 실행할 명령 → 보여야 할 결과 → 답할 내용**을 순서대로 적었습니다. 위에서부터 그대로 따라 하면 평가표 항목 1~4를 모두 확인할 수 있습니다.

[← README](../README.md) · [개념과 배경](concepts.md) · [평가 정리 (말하기 예시)](evaluation.md)

| 표시 | 어디서 실행 | 프롬프트 |
|---|---|---|
| `[Mac]` | Mac 터미널 | `codewhite77770105@cx2r6s7 ~ %` |
| `[탭 1]` | VM, agent-admin (앱 전용 창) | `agent-admin@b4-1:~/agent-app$` |
| `[탭 2]` | VM, arang (확인용 창) | `arang@b4-1:~/codyssey_B4-1$` |

> 명령을 치기 전에 **마지막 줄의 프롬프트**로 위치를 확인하세요. Mac에서 `sudo`를 치면 Mac 관리자 비밀번호를 묻습니다.

---

## 0. 준비 (평가 시작 전 3분)

```bash
open ~/Applications/UTM.app                 # [Mac] b4-1이 멈춰 있으면 ▶, 1분 대기
```

**탭 1: 앱 켜기**
```bash
ssh -p 20022 arang@192.168.64.2             # [Mac]
sudo -iu agent-admin                        # → agent-admin@b4-1
cd $AGENT_HOME
./agent-app-linux-x86                       # Boot 5단계 [OK] → Agent READY. 이 창은 그대로 둠
```

**탭 2: 확인용 창** (Mac 터미널에서 ⌘T)
```bash
ssh -p 20022 arang@192.168.64.2             # [Mac]
cd ~/codyssey_B4-1
sudo -v                                     # arang 비밀번호를 미리 한 번 넣어 둠 (15분간 다시 안 물음)
```

---

## 항목 1. 결과물이 요구사항대로 동작하는가

### 1-1. SSH 포트 20022, root 원격 접속 차단

```bash
sudo sshd -T | grep -E "^port |^permitrootlogin "        # [탭 2]
```
✅ `port 20022`, `permitrootlogin no` → sshd가 **실제로 쓰는** 규칙

```bash
sudo ss -tlnp | grep sshd                                 # [탭 2]
```
✅ `LISTEN ... 0.0.0.0:20022 ... "sshd"` → 20022번 문이 **실제로 열림**

```bash
ssh -p 20022 root@192.168.64.2                            # [Mac] 새 탭, 비밀번호는 아무거나
```
✅ `Permission denied` → root는 **실제로 거절** (Ctrl+C로 빠져나옴)

📸 [1-1](images/evidence/1-1_sshd_rules.png) · [1-2](images/evidence/1-2_sshd_listen.png) · [1-3](images/evidence/1-3_root_denied.png)

### 1-2. 방화벽 활성화, 20022/tcp · 15034/tcp만 허용

```bash
sudo ufw status verbose                                   # [탭 2]
```
✅ `Status: active`, `Default: deny (incoming)`, 허용 목록에 `20022/tcp`, `15034/tcp`만 (`(v6)` 줄은 IPv6용)

📸 [2](images/evidence/2_ufw_status.png)

### 1-3. 계정 3개, 그룹 2개

```bash
id agent-admin; id agent-dev; id agent-test               # [탭 2]
```
✅ admin · dev → `agent-common`, `agent-core` / test → `agent-common`만 (맨 앞 같은 이름 그룹은 자동 개인 그룹)

📸 [3](images/evidence/3_id_groups.png)

### 1-4. Boot Sequence 5단계 [OK], Agent READY

**[탭 1]** 화면을 보여 줍니다. (0. 준비에서 켠 화면을 위로 스크롤)

✅ `[1/5]` ~ `[5/5]` 모두 `[OK]` → `All Boot Checks Passed!` → `Agent READY`

```bash
sudo ss -ltnp | grep 15034                                # [탭 2]
```
✅ `LISTEN ... 0.0.0.0:15034 ... "agent-app-linux"` → 앱이 15034를 엶

📸 [6](images/evidence/6_boot_ready.png) · [6-2](images/evidence/6-2_app_listen.png)

### 1-5. monitor.sh가 프로세스 · 포트를 점검하고, 비정상이면 exit 1

**① 정상일 때**
```bash
sudo -u agent-admin /home/agent-admin/agent-app/bin/monitor.sh; echo "exit=$?"     # [탭 2]
```
✅ 프로세스 · 포트 · 방화벽 `[OK]`, CPU · MEM · DISK 출력, `exit=0` (MEM 경고가 떠도 exit=0)

**② 앱을 끈 뒤**
- **[탭 1]**에서 Ctrl+C → `Shutting down gracefully` 후 프롬프트로 돌아옴
```bash
/home/agent-admin/agent-app/bin/monitor.sh; echo "exit=$?"                        # [탭 1] agent-admin은 sudo 없이
```
✅ `[FAIL] not running` → 바로 멈춤 → `exit=1`

- 확인 후 **[탭 1]**에서 `./agent-app-linux-x86`으로 앱을 다시 켭니다.

📸 [7-2](images/evidence/7-2_monitor_ok.png) · [7-4](images/evidence/7-4_monitor_fail.png)

### 1-6. monitor.log가 지정 포맷으로 누적

```bash
sudo tail -5 /var/log/agent-app/monitor.log               # [탭 2]
```
✅ `[YYYY-MM-DD HH:MM:SS] PID:... CPU:..% MEM:..% DISK_USED:..%` 형식으로 여러 줄

📸 [8-2](images/evidence/8-2_monitor_log.png)

### 1-7. cron 매분 실행으로 자동 증가

```bash
sudo crontab -u agent-admin -l                            # [탭 2]
```
✅ `* * * * * /home/agent-admin/agent-app/bin/monitor.sh > /dev/null 2>&1`

```bash
sudo tail -f /var/log/agent-app/monitor.log               # [탭 2] 1~2분 지켜본 뒤 Ctrl+C
```
✅ 매분 `:02`초쯤 **새 줄이 저절로** 추가됨 (앱이 켜져 있어야 함)

📸 [8-1](images/evidence/8-1_crontab.png) · [8-2](images/evidence/8-2_monitor_log.png)

### 1-8. 용량 관리 10MB / 10개 설정, 동작 설명

```bash
cat /etc/logrotate.d/agent-app                            # [탭 2]
```
✅ `size 10M`, `rotate 10`

```bash
sudo logrotate -d /etc/logrotate.d/agent-app              # [탭 2] -d = 판단만 (실제로 자르지 않음)
```
✅ `10485760 bytes (10 rotations)`, `log does not need rotating` (아직 10MB 미만)

**동작 설명:** 하루 한 번 크기를 보고, 10MB를 넘으면 `monitor.log` → `monitor.log.1`로 바꾸고 새 파일을 만든다. 예전 것은 한 칸씩 밀리고 `.10`을 넘는 것은 지운다.

📸 [8-3](images/evidence/8-3_logrotate_conf.png) · [8-4](images/evidence/8-4_logrotate_dryrun.png)

---

## 항목 2. 구현 방법을 설명할 수 있는가

### 2-1. 프로세스 식별 · 포트 확인 명령과 선택 이유

```bash
sed -n '45,59p' bin/monitor.sh                            # [탭 2] 프로세스 · 포트 확인 코드
```

```bash
pgrep -a -f "^[^ ]*agent-app-linux"                        # [탭 2] monitor.sh와 같은 패턴
```
✅ `./agent-app-linux-x86` 2줄 (부모 · 자식). monitor.sh는 `-o`로 먼저 뜬 부모의 PID를 씀

**답할 내용**
- `pgrep`: 결과가 **PID 숫자**라 비었는지만 보면 되고 로그에 그대로 씀. `ps | grep`은 grep 자신이 걸림
- 패턴 `^[^ ]*`: 명령줄의 **첫 단어**가 앱일 때만 → 이름만 들어간 다른 프로세스를 앱으로 착각하지 않음
- `ss -ltn`: Ubuntu 기본 설치, LISTEN 중인 TCP 포트만 숫자로. `netstat`은 기본 설치가 아닌 예전 도구

### 2-2. CPU · MEM · DISK 추출 방식, 로그 포맷을 고정한 이유

```bash
sed -n '76,97p' bin/monitor.sh                            # [탭 2] 자원 수집 코드
```

**답할 내용**
- CPU: `/proc/stat`을 **1초 간격으로 두 번** 읽고 그 차이로 "쉬지 않은 비율" 계산 (누적값이라 한 번만 읽으면 의미 없음)
- MEM: `free`의 Mem 줄 → used ÷ total × 100
- DISK: `df -P /`의 Use% (`-P`로 한 줄 출력 고정 → 칸 위치가 항상 같음)
- 포맷 고정: 한 줄 = 한 번 측정, 칸 순서가 같아서 `grep`(시각 찾기) · `awk`(평균)로 **프로그램이 읽을 수 있는 데이터**가 됨

### 2-3. 소유자(agent-dev)와 실행자(agent-admin, cron) 권한 정책

```bash
sudo ls -l /home/agent-admin/agent-app/bin/monitor.sh     # [탭 2]
```
✅ `-rwxr-x--- agent-dev agent-core` (750)

```bash
sudo -u agent-test /home/agent-admin/agent-app/bin/monitor.sh      # [탭 2]
```
✅ `Permission denied` → test는 실행도 못 함

**답할 내용:** 주인 agent-dev는 `rwx`(수정 가능), 그룹 agent-core는 `r-x`라 core인 admin은 **실행만** 가능 → admin의 cron이 돌릴 수 있고 실수로 고칠 수 없음. 나머지는 `---`.

📸 [7-1](images/evidence/7-1_monitor_perm.png)

### 2-4. 용량 기반 로그 관리 구현 방식

1-8과 같은 명령으로 보여 줍니다.

**답할 내용:** 스크립트로 직접 짜지 않고 Ubuntu 기본 도구 **logrotate**를 썼다. 이미 하루 한 번 자동으로 돌고 있고 설정 6줄로 끝난다. 한 줄 약 65바이트라 하루 약 94KB씩 쌓여서 하루 한 번 검사로 충분하다.

---

## 항목 3. 개념을 설명할 수 있는가

### 3-1. SSH 포트 변경 · root 차단이 왜 효과적인가 (위협 모델)

```bash
ssh -o ConnectTimeout=5 -p 22 arang@192.168.64.2          # [Mac] 옛 22번 문으로 접속 시도
```
✅ `Operation timed out` → 22번은 닫혀 있음 (봇이 두드리는 기본 문)

**답할 내용:** 봇은 "22번 포트 + root + 비밀번호 대입" 순서로 공격한다. 포트를 바꾸면 무작위 시도가 줄고, root를 막으면 비밀번호를 맞혀도 root로 못 들어온다. 포트 변경은 숨기기일 뿐이라 방화벽 · root 차단과 **겹쳐서** 쓴다.

### 3-2. api_keys · 로그를 agent-core로 제한한 이유 (최소 권한)

```bash
sudo -u agent-test ls /home/agent-admin/agent-app/api_keys      # [탭 2]
```
✅ `Permission denied`

```bash
sudo -u agent-dev ls -la /home/agent-admin/agent-app/api_keys   # [탭 2]
```
✅ 목록이 보임 → **같은 폴더, 사람에 따라 다른 결과**

**답할 내용:** 일에 필요한 만큼만 준다. 키가 새면 도용되고, 로그가 지워지면 사고 원인을 못 찾는다. test는 볼 일이 없으니 처음부터 막아, 실수하거나 탈취돼도 피해가 번지지 않게 했다.

📸 [4-2](images/evidence/4-2_test_denied.png) · [4-3](images/evidence/4-3_dev_allowed.png)

### 3-3. 경고만 하는 항목을 분리한 운영상 이유

```bash
sudo ufw disable                                                                   # [탭 2]
sudo -u agent-admin /home/agent-admin/agent-app/bin/monitor.sh; echo "exit=$?"
sudo ufw enable                                                                    # y 입력 (꼭 다시 켜기)
```
✅ `[WARNING] Firewall (ufw) is not active`인데도 자원 측정 · 기록까지 하고 `exit=0`

(앱이 죽었을 때 `exit=1`로 멈추는 것은 1-5에서 확인)

**답할 내용:** 기준은 "서비스가 돌고 있나". 앱이 죽으면 이미 멈춘 것이라 exit 1로 확실히 알린다. 방화벽이 꺼지거나 자원이 높아도 서비스는 돌고 있어서, 여기서 멈추면 **기록이 끊겨 추세를 잃는다.** 그래서 경고만 하고 계속 기록한다.

📸 [7-3](images/evidence/7-3_monitor_fw_warn.png)

### 3-4. `>`와 `>>`의 차이, 로그에 `>>`가 필요한 이유

```bash
echo "1번째" > /tmp/over.txt;  echo "2번째" > /tmp/over.txt;  echo "3번째" > /tmp/over.txt       # [탭 2]
cat /tmp/over.txt
```
✅ `3번째` 한 줄만 → **덮어쓰기**

```bash
echo "1번째" >> /tmp/add.txt;  echo "2번째" >> /tmp/add.txt;  echo "3번째" >> /tmp/add.txt
cat /tmp/add.txt
```
✅ 3줄 모두 → **이어쓰기**

```bash
sed -n '105,108p' bin/monitor.sh                          # monitor.sh의 기록 줄 (>> 사용)
```

**답할 내용:** 모니터링 로그의 가치는 과거와 비교하는 것. 장애 직전 몇 분의 흐름을 보려면 기록이 쌓여 있어야 해서 `>>`를 썼다.

---

## 항목 4. 상황이 바뀌면 어떻게 하는가

### 4-1. 대상이 Nginx로 바뀌면 바꿀 곳

```bash
sed -n '17,26p' bin/monitor.sh                            # [탭 2] 바꿀 값이 모여 있는 곳
```
✅ `APP_NAME`, `APP_PORT`, `LOG_DIR`, `CPU_LIMIT` · `MEM_LIMIT` · `DISK_LIMIT`

**답할 내용:** 구조(확인 → 수집 → 경고 → 기록)는 그대로, 맨 위 값만 바꾼다.

| 항목 | 지금 | Nginx라면 |
|---|---|---|
| 프로세스 | `agent-app-linux` | `pgrep -x nginx` |
| 포트 | 15034 | 80 / 443 (방화벽도 열기) |
| 로그 | monitor.log | access.log · error.log도 같이 보기 (5xx 증가 = 살아 있지만 고장) |
| 임계값 | CPU 20 · MEM 10 · DISK 80 | 평소 트래픽 값을 며칠 기록해 보고 다시 정함 |

### 4-2. 프로세스는 있는데 포트가 안 열리면: 확인 순서

이 순서로 명령을 하나씩 칩니다. (앱이 켜진 상태에서 명령 쓰는 법만 보여 줌)

```bash
pgrep -a -f "^[^ ]*agent-app-linux"                       # [탭 2] ① 프로세스가 정말 있나, PID는?
sudo ss -ltnp | grep 15034                                # ② 15034를 누가 쓰고 있나 (다른 프로그램?)
sudo grep AGENT_PORT /home/agent-admin/.bashrc            # ③ 앱에 준 포트 번호가 맞나 (15034)
ps -o pid,stat,etime,cmd -p $(pgrep -o -f "^[^ ]*agent-app-linux")   # ④ 앱이 멈춰 있지 않나 (STAT이 T면 정지)
```

**답할 내용:** 빠르고 흔한 원인부터. ① 앱 출력에서 Boot 몇 단계에서 멈췄나 → ② 포트를 다른 프로그램(예전 앱)이 차지했나 → ③ 환경변수 포트 번호 오타 → ④ 앱 자체가 멈춤. 그래도 모르면 Ctrl+C로 끄고 다시 실행해 출력을 비교한다.

### 4-3. 로그가 급증해 디스크가 찰 위험: 단기 · 중기 대응

```bash
df -h /                                                   # [탭 2] 디스크가 얼마나 찼나
sudo du -sh /var/log/agent-app/*                          # 어떤 로그가 큰가
```
✅ monitor.log보다 앱 자체 로그(`agent_app.log`)가 훨씬 빨리 큼 (1분에 약 3.3KB)

**답할 내용**
- **단기:** `df` · `du`로 원인 찾기 → 지금 쓰는 로그는 `rm` 대신 `: > 파일`로 비우기(열린 파일을 지우면 공간이 바로 안 돌아옴) → 오래된 `.1` ~ `.10` 압축 · 정리 → 같은 에러가 반복되면 원인 프로세스 재시작
- **중기:** logrotate 기준 낮추기 · 압축 켜기, `agent_app.log`도 logrotate에 추가, 로그 전용 파티션 분리, DISK 80% 경고를 알림으로 연결, 로그를 쏟아내는 코드 수정

---

## 끝나고 원래대로

| 할 일 | 명령 |
|---|---|
| 방화벽이 켜져 있는지 | `sudo ufw status` → `Status: active` (3-3에서 껐다면 `sudo ufw enable`) |
| 앱이 켜져 있는지 | `pgrep -a -f "^[^ ]*agent-app-linux"` → 비어 있으면 [탭 1]에서 `./agent-app-linux-x86` |
| 3-4 시험 파일 | `rm /tmp/over.txt /tmp/add.txt` |
