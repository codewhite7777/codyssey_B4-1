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

## 3단계. 계정 · 그룹 만들기 (진행 중)

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
```
