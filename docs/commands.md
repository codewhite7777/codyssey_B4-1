# 명령어 기록 (내 VM에서 실제로 실행한 순서)

과제 제출물 "설정/명령어 기록"입니다. 설명은 [README](../README.md)에 있고, 여기에는 **실제로 실행한 명령만** 순서대로 적습니다.

- 환경: 교육장 iMac (Intel, x86_64) + UTM, Ubuntu Server 22.04.5 LTS
- VM 주소: `192.168.64.2`, 내 계정: `arang`
- 📸 = 증거 화면을 찍은 명령 ([docs/images/evidence/](images/evidence/))

| 표시 | 어디서 실행 |
|---|---|
| `[Mac]` | Mac 터미널 (`codewhite77770105@cx2r6s7 ~ %`) |
| `[VM]` | ssh로 접속한 VM (`arang@b4-1:~$`) |

---

## 0단계. 준비

```bash
# [Mac] VM 접속 (이때는 아직 22번 포트)
ssh arang@192.168.64.2

# [Mac] 앱 파일을 VM으로 복사
scp ~/Downloads/agent-app/agent-app-linux-x86 arang@192.168.64.2:~/

# [VM] 시간대를 한국 시간으로
sudo timedatectl set-timezone Asia/Seoul

# [VM] 저장소 받기, 프로그램 설치
git clone https://github.com/codewhite7777/codyssey_B4-1.git
cd ~/codyssey_B4-1
sudo apt update
sudo apt install -y openssh-server ufw acl cron logrotate
```

## 1단계. SSH 잠그기

```bash
# [VM] 설정 파일 백업 → 포트 20022, root 차단으로 수정 → 확인
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
sudo sed -i 's/^#\?Port .*/Port 20022/; s/^#\?PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
grep -nE "^Port|^PermitRootLogin" /etc/ssh/sshd_config

# [VM] 문법 검사 → 재시작
sudo sshd -t && echo "문법 OK"
sudo systemctl restart ssh

# [Mac] 새 탭에서 새 포트로 접속되는지 확인
ssh -p 20022 arang@192.168.64.2

# [VM] 📸 1-1 적용된 규칙
sudo sshd -T | grep -E "^port |^permitrootlogin "

# [VM] 📸 1-2 20022번에서 LISTEN
sudo ss -tlnp | grep sshd

# [Mac] 📸 1-3 root 접속 거절
ssh -p 20022 root@192.168.64.2
```

## 2단계. 방화벽 켜기

```bash
# [VM] 현재 상태 (inactive)
sudo ufw status

# [VM] 기본 규칙: 들어오는 것 거절, 나가는 것 허용
sudo ufw default deny incoming
sudo ufw default allow outgoing

# [VM] 허용 명단: SSH 20022, 앱 15034
sudo ufw allow 20022/tcp
sudo ufw allow 15034/tcp

# [VM] 켜기 전 명단 확인 → 켜기 (y 입력)
sudo ufw show added
sudo ufw enable

# [VM] 📸 2 최종 상태
sudo ufw status verbose
```

## 3단계. 계정 · 그룹 만들기

```bash
# [VM] 계정 만들기
sudo useradd -m -s /bin/bash agent-admin
sudo useradd -m -s /bin/bash agent-dev
sudo useradd -m -s /bin/bash agent-test

# [VM] 그룹 만들기
sudo groupadd agent-common
sudo groupadd agent-core

# [VM] 그룹에 넣기 (admin, dev → 두 그룹 / test → common만)
sudo usermod -aG agent-common,agent-core agent-admin
sudo usermod -aG agent-common,agent-core agent-dev
sudo usermod -aG agent-common agent-test

# [VM] 📸 3 확인
id agent-admin
id agent-dev
id agent-test
```

## 4단계. 폴더 · 권한 정하기

```bash
# [VM] 폴더 만들기 → 확인 (처음에는 주인이 root)
sudo mkdir -p /home/agent-admin/agent-app/upload_files /home/agent-admin/agent-app/api_keys /home/agent-admin/agent-app/bin /var/log/agent-app
sudo ls -l /home/agent-admin/agent-app

# [VM] 홈 폴더에 agent-common "통과(x)"만 허용 (ACL) → 확인
sudo setfacl -m g:agent-common:x /home/agent-admin
getfacl /home/agent-admin

# [VM] 앱 폴더(AGENT_HOME): 주인 agent-admin, 그룹 agent-common
sudo chown agent-admin:agent-common /home/agent-admin/agent-app
sudo chmod 750 /home/agent-admin/agent-app
sudo ls -ld /home/agent-admin/agent-app

# [VM] 공용 폴더(upload_files): 주인 agent-admin, 그룹 agent-common
sudo chown agent-admin:agent-common /home/agent-admin/agent-app/upload_files
sudo chmod 2770 /home/agent-admin/agent-app/upload_files
sudo ls -ld /home/agent-admin/agent-app/upload_files

# [VM] 공용 폴더 기본 ACL: 앞으로 생길 파일도 agent-common이 읽기·쓰기
sudo setfacl -d -m g:agent-common:rwx /home/agent-admin/agent-app/upload_files
getfacl /home/agent-admin/agent-app/upload_files        # arang은 "나머지"라 Permission denied (정상)
sudo getfacl /home/agent-admin/agent-app/upload_files

# [Mac] (SSH가 끊겨서 다시 접속)
ssh -p 20022 arang@192.168.64.2

# [VM] 비밀 폴더(api_keys): 주인 agent-admin, 그룹 agent-core
sudo chown agent-admin:agent-core /home/agent-admin/agent-app/api_keys
sudo ls -ld /home/agent-admin/agent-app/api_keys
sudo chmod 2770 /home/agent-admin/agent-app/api_keys
sudo ls -ld /home/agent-admin/agent-app/api_keys

# [VM] bin 폴더: 주인 agent-dev(monitor.sh 작성자), 그룹 agent-core
sudo chown agent-dev:agent-core /home/agent-admin/agent-app/bin
sudo chmod 750 /home/agent-admin/agent-app/bin
sudo ls -ld /home/agent-admin/agent-app/bin

# [VM] 로그 폴더: 주인 agent-admin, 그룹 agent-core
sudo chown agent-admin:agent-core /var/log/agent-app
sudo chmod 2770 /var/log/agent-app
sudo ls -ld /var/log/agent-app

# [VM] 로그 폴더 기본 ACL: 앞으로 생길 로그 파일도 agent-core가 읽기·쓰기
sudo setfacl -d -m g:agent-core:rw /var/log/agent-app
sudo getfacl /var/log/agent-app

# [VM] 📸 4-1 폴더 5개 한눈에
sudo ls -ld /home/agent-admin/agent-app /home/agent-admin/agent-app/upload_files /home/agent-admin/agent-app/api_keys /home/agent-admin/agent-app/bin /var/log/agent-app

# [VM] 계정별 접근 시험 (sudo -u 계정 = 그 계정 권한으로 실행)
sudo -u agent-test touch /home/agent-admin/agent-app/upload_files/from-test.txt    # 공용 폴더 쓰기: 성공
sudo -u agent-test ls /home/agent-admin/agent-app/api_keys                         # 비밀 폴더: Permission denied
sudo -u agent-test ls /var/log/agent-app                                           # 로그 폴더: Permission denied
sudo -u agent-dev ls -la /home/agent-admin/agent-app/api_keys                      # dev는 비밀 폴더 통과 (📸 4-2 test 거절, 4-3 dev 통과)
```

## 5단계. 환경변수 + 키 파일

```bash
# [VM] agent-admin으로 바꾸기 (프롬프트가 agent-admin@b4-1로 바뀜, 이후 sudo 없음)
sudo -iu agent-admin

# [VM: agent-admin] 환경변수 5개를 ~/.bashrc 끝에 추가
cat >> ~/.bashrc <<'EOF'

# ---- agent-app 실행 환경 ----
export AGENT_HOME=/home/agent-admin/agent-app
export AGENT_PORT=15034
export AGENT_UPLOAD_DIR=$AGENT_HOME/upload_files
export AGENT_KEY_PATH=$AGENT_HOME/api_keys
export AGENT_LOG_DIR=/var/log/agent-app
EOF

# [VM: agent-admin] 지금 창에 적용 → 📸 5-1 확인
source ~/.bashrc
env | grep ^AGENT_ | sort

# [VM: agent-admin] 키 파일 (앱이 읽는 이름: secret.key) → 내용 확인
echo "agent_api_key_test" > $AGENT_KEY_PATH/secret.key
cat $AGENT_KEY_PATH/secret.key

# [VM: agent-admin] 과제 문서에 적힌 이름도 같은 내용으로 (앱은 읽지 않음)
echo "agent_api_key_test" > $AGENT_KEY_PATH/t_secret.key

# [VM: agent-admin] 키 파일 권한 660 → 📸 5-2 확인
chmod 660 $AGENT_KEY_PATH/*.key
ls -l $AGENT_KEY_PATH
```

## 6단계. 앱 실행

```bash
# [VM: agent-admin] arang으로 돌아가기
exit

# [VM: arang] 앱 파일을 AGENT_HOME으로 (복사 + 주인 agent-admin + 권한 750) → 확인
sudo install -o agent-admin -g agent-admin -m 750 ~/agent-app-linux-x86 /home/agent-admin/agent-app/agent-app-linux-x86
sudo ls -l /home/agent-admin/agent-app

# [VM: arang] agent-admin으로 바꾸고 AGENT_HOME으로 이동
sudo -iu agent-admin
cd $AGENT_HOME

# [VM: agent-admin] 📸 6 앱 실행 → Boot 5단계 [OK], Agent READY (이 창은 켜 둠, 종료는 Ctrl+C)
./agent-app-linux-x86

# [Mac] 새 탭에서 다시 접속 (탭 1 = 앱 실행 중, 탭 2 = 작업용)
ssh -p 20022 arang@192.168.64.2

# (이틀 뒤 SSH가 끊기며 앱도 종료됨 → 다시 실행)
# [Mac] 탭 1 접속 → [VM] 앱이 살아 있는지 확인 (아무것도 안 나오면 꺼진 것)
ssh -p 20022 arang@192.168.64.2
pgrep -a -f "^[^ ]*agent-app-linux"

# [VM] 탭 1에서 앱 다시 실행 → Boot 5단계 [OK], Agent READY
sudo -iu agent-admin
cd $AGENT_HOME
./agent-app-linux-x86

# [Mac] 새 탭(탭 2)에서 접속 → [VM] 📸 6-2 앱이 15034에서 LISTEN
ssh -p 20022 arang@192.168.64.2
sudo ss -ltnp | grep 15034
```

## 7단계. monitor.sh (진행 중)

```bash
# [VM: arang] 저장소 폴더로 이동, 설치할 파일 확인
cd ~/codyssey_B4-1
ls bin config

# [VM: arang] monitor.sh 설치 (복사 + 주인 agent-dev + 그룹 agent-core + 권한 750) → 📸 7-1 확인
sudo install -o agent-dev -g agent-core -m 750 bin/monitor.sh /home/agent-admin/agent-app/bin/monitor.sh
sudo ls -l /home/agent-admin/agent-app/bin

# [VM: arang] agent-core에게 "ufw status" 한 명령만 sudo 허용 → 문법 검사 (parsed OK)
sudo install -o root -g root -m 0440 config/sudoers-agent-monitor /etc/sudoers.d/agent-monitor
sudo visudo -cf /etc/sudoers.d/agent-monitor

# [VM: arang] 규칙 시험: 허용한 명령은 됨, 단어 하나만 달라도 거절
sudo -u agent-admin sudo -n /usr/sbin/ufw status              # Status: active
sudo -u agent-admin sudo -n /usr/sbin/ufw status verbose      # sudo: a password is required

# [VM: arang] 📸 7-2 monitor.sh를 agent-admin으로 실행 (정상: [OK] 3개, MEM 경고, exit=0)
sudo -u agent-admin /home/agent-admin/agent-app/bin/monitor.sh; echo "exit=$?"
```
