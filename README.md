# B4-1 · 컴퓨터가 알아서 자기 상태를 점검하게 만들기

> 리눅스 서버를 안전하게 세팅하고(SSH · 방화벽 · 계정 · 권한), 제공 앱을 1분마다 자동으로 점검하고 기록하는 `monitor.sh`를 만든 과제입니다.

**환경:** 교육장 iMac(Intel) + UTM, Ubuntu Server 22.04.5 LTS (x86_64) · **방화벽:** UFW · **범위:** 필수 요구사항만

![전체 흐름](docs/images/overview.svg)

## 결과 요약

모든 요구사항을 내 VM에서 확인했고, 사진은 [docs/steps.md](docs/steps.md)에 단계별로 있습니다.

| 과제 요구사항 | 결과 | 확인 (📸 증거 사진) |
|---|---|---|
| SSH 포트 20022, root 원격 로그인 차단 | ✅ | [1단계](docs/steps.md#1단계-ssh-잠그기) · [1-1](docs/images/evidence/1-1_sshd_rules.png) [1-2](docs/images/evidence/1-2_sshd_listen.png) [1-3](docs/images/evidence/1-3_root_denied.png) |
| UFW 활성화, 20022/tcp · 15034/tcp만 허용 | ✅ | [2단계](docs/steps.md#2단계-방화벽-켜기) · [2](docs/images/evidence/2_ufw_status.png) |
| 계정 3개, 그룹 2개 (common: 3명 / core: admin · dev) | ✅ | [3단계](docs/steps.md#3단계-계정--그룹) · [3](docs/images/evidence/3_id_groups.png) |
| upload_files = common R/W, api_keys · 로그 = core만 R/W | ✅ | [4단계](docs/steps.md#4단계-폴더--권한) · [4-1](docs/images/evidence/4-1_dirs.png) [4-2](docs/images/evidence/4-2_test_denied.png) [4-3](docs/images/evidence/4-3_dev_allowed.png) |
| 환경변수 5개, 키 파일 | ✅ | [5단계](docs/steps.md#5단계-환경변수--키-파일) · [5-1](docs/images/evidence/5-1_env.png) [5-2](docs/images/evidence/5-2_keys.png) |
| Boot 5단계 [OK], Agent READY, 0.0.0.0:15034 | ✅ | [6단계](docs/steps.md#6단계-앱-실행) · [6](docs/images/evidence/6_boot_ready.png) [6-2](docs/images/evidence/6-2_app_listen.png) |
| monitor.sh 권한(agent-dev · agent-core · 750), 비정상 시 exit 1, 경고는 출력만 | ✅ | [7단계](docs/steps.md#7단계-monitorsh) · [7-1](docs/images/evidence/7-1_monitor_perm.png) [7-2](docs/images/evidence/7-2_monitor_ok.png) [7-3](docs/images/evidence/7-3_monitor_fw_warn.png) [7-4](docs/images/evidence/7-4_monitor_fail.png) |
| cron 매분 실행, monitor.log 지정 포맷으로 누적 | ✅ | [8단계](docs/steps.md#8단계-cron--logrotate) · [8-1](docs/images/evidence/8-1_crontab.png) [8-2](docs/images/evidence/8-2_monitor_log.png) |
| 로그 용량 관리 10MB / 10개 (logrotate) | ✅ | [8단계](docs/steps.md#8단계-cron--logrotate) · [8-3](docs/images/evidence/8-3_logrotate_conf.png) [8-4](docs/images/evidence/8-4_logrotate_dryrun.png) |

> **과제 문서와 다른 점:** 제공 앱이 `AGENT_KEY_PATH`를 **폴더**로, 키 파일 이름을 **`secret.key`**로 요구해서(문서대로 하면 Boot FAIL) 앱 기준을 따랐습니다. ([이유](docs/concepts.md#6-환경변수와-키-파일))

<details>
<summary><b>평가표 확인 명령 모음</b> (펼치기)</summary>

`[Mac]` = Mac 터미널, `[탭 1]` = VM의 agent-admin 창(앱 실행 중), 나머지는 VM의 arang 창(`~/codyssey_B4-1`).

```bash
# 준비
ssh -p 20022 arang@192.168.64.2          # [Mac] 탭 1
sudo -iu agent-admin                     # [탭 1] agent-admin으로 바꾼 뒤
cd $AGENT_HOME
./agent-app-linux-x86                    # [탭 1] 앱 실행, 창은 그대로
ssh -p 20022 arang@192.168.64.2          # [Mac] 탭 2 (⌘T)
cd ~/codyssey_B4-1 && sudo -v

# 항목 1
sudo sshd -T | grep -E "^port |^permitrootlogin "        # 1-1 port 20022 / permitrootlogin no
sudo ss -tlnp | grep sshd                                 # 1-1 0.0.0.0:20022 LISTEN
ssh -p 20022 root@192.168.64.2                            # 1-1 [Mac] Permission denied
sudo ufw status verbose                                   # 1-2 active, 20022 · 15034만
id agent-admin; id agent-dev; id agent-test               # 1-3 admin·dev: common,core / test: common
sudo ss -ltnp | grep 15034                                # 1-4 0.0.0.0:15034 LISTEN (탭 1: [OK]×5, Agent READY)
sudo -u agent-admin /home/agent-admin/agent-app/bin/monitor.sh; echo "exit=$?"   # 1-5 [OK]×3, exit=0
/home/agent-admin/agent-app/bin/monitor.sh; echo "exit=$?"                       # 1-5 [탭 1] Ctrl+C 후: [FAIL], exit=1
sudo tail -5 /var/log/agent-app/monitor.log               # 1-6 지정 포맷으로 여러 줄
sudo crontab -u agent-admin -l                            # 1-7 * * * * * .../monitor.sh
sudo tail -f /var/log/agent-app/monitor.log               # 1-7 1분마다 새 줄 (Ctrl+C)
cat /etc/logrotate.d/agent-app                            # 1-8 size 10M / rotate 10
sudo logrotate -d /etc/logrotate.d/agent-app              # 1-8 10485760 bytes (10 rotations)

# 항목 2
sed -n '45,59p' bin/monitor.sh                            # 2-1 pgrep · ss 코드
sed -n '76,97p' bin/monitor.sh                            # 2-2 /proc/stat · free · df 코드
sudo ls -l /home/agent-admin/agent-app/bin/monitor.sh     # 2-3 -rwxr-x--- agent-dev agent-core
sudo -u agent-test /home/agent-admin/agent-app/bin/monitor.sh   # 2-3 Permission denied

# 항목 3
ssh -o ConnectTimeout=5 -p 22 arang@192.168.64.2          # 3-1 [Mac] 22번은 timed out
sudo -u agent-test ls /home/agent-admin/agent-app/api_keys      # 3-2 Permission denied
sudo -u agent-dev ls -la /home/agent-admin/agent-app/api_keys   # 3-2 목록 보임
sudo ufw disable                                          # 3-3 ↓ [WARNING] Firewall, exit=0
sudo -u agent-admin /home/agent-admin/agent-app/bin/monitor.sh; echo "exit=$?"
sudo ufw enable                                           # 3-3 꼭 다시 켜기 (y)
echo 1 > /tmp/o; echo 2 > /tmp/o; cat /tmp/o              # 3-4 덮어쓰기: 2만
echo 1 >> /tmp/a; echo 2 >> /tmp/a; cat /tmp/a            # 3-4 이어쓰기: 1, 2

# 항목 4
sed -n '17,26p' bin/monitor.sh                            # 4-1 바꿀 값 (앱 이름, 포트, 로그, 임계값)
sudo ss -ltnp | grep 15034                                # 4-2 포트를 누가 쓰나
ps -o pid,stat,etime,cmd -p $(pgrep -o -f "^[^ ]*agent-app-linux")   # 4-2 앱이 멈춰 있나
df -h / && sudo du -sh /var/log/agent-app/*               # 4-3 디스크 · 로그 크기
```

질문별 설명과 말하기 예시: [docs/evaluation.md](docs/evaluation.md)

</details>

## 문서 안내

| 파일 | 내용 |
|---|---|
| [docs/steps.md](docs/steps.md) | 단계별 수행 내역: 핵심 명령 + 📸 증거 사진 20장 |
| [docs/evaluation.md](docs/evaluation.md) | 평가표 기준 정리: 질문마다 설명 → 실행 → 말하기 |
| [docs/commands.md](docs/commands.md) | 설정 · 명령어 기록: 내 VM에서 실행한 순서 그대로 |
| [docs/concepts.md](docs/concepts.md) | 개념과 배경: 제공 앱, UTM을 고른 이유, 권한 · cron 설명 |
| [bin/monitor.sh](bin/monitor.sh) | 자동화 스크립트 (Bash) |
| [config/](config/) | logrotate 설정 (10MB / 10개), sudoers 설정 (`ufw status`만 허용) |
