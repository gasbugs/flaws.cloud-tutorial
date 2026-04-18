# AWS 보안 primer — flaws.cloud / flaws2.cloud 진입 전 필독

이 문서는 flaws.cloud 와 flaws2.cloud 가 **반복해서 찔러보는** AWS 서비스들의 보안 관련 핵심 개념만 짧게 압축한 것입니다. 이미 친숙하다면 건너뛰어도 좋지만, "왜 이 명령이 통하는가" 를 설명할 때 이 문서를 인용합니다.

## 📋 목차
1. [공통 원칙 — IAM Principal / 정책 평가](#1-공통-원칙--iam-principal--정책-평가)
2. [S3 — 버킷·객체·ACL·정책·Block Public Access](#2-s3--버킷객체aclpolicyblock-public-access)
3. [IAM 사용자 vs 역할 vs STS 임시 자격증명](#3-iam-사용자-vs-역할-vs-sts-임시-자격증명)
4. [EC2 IMDS v1 vs v2](#4-ec2-imds-v1-vs-v2)
5. [ECS Task Role 과 Task Metadata Endpoint](#5-ecs-task-role-과-task-metadata-endpoint)
6. [Lambda 와 API Gateway 기본 보안 포인트](#6-lambda-와-api-gateway-기본-보안-포인트)
7. [CloudTrail — 무엇이 기록되고 무엇이 안 되는가](#7-cloudtrail--무엇이-기록되고-무엇이-안-되는가)
8. [EBS 스냅샷의 공개 공유](#8-ebs-스냅샷의-공개-공유)
9. [Access Key 탐지 패턴](#9-access-key-탐지-패턴)

---

## 1. 공통 원칙 — IAM Principal / 정책 평가

AWS 의 모든 API 호출은 누구(Principal)인가 → 어떤 행동(Action)을 → 어떤 자원(Resource)에 대해 → 어떤 조건(Condition)에서 수행하는지를 검사한다. 정책이 여러 곳에 붙을 수 있다:

| 붙는 곳 | 예 | 우선순위 규칙 |
|---------|-----|---------------|
| **Identity 기반** | 사용자/역할/그룹에 첨부 | 허용(Allow)이 있어야 함 |
| **Resource 기반** | 버킷 정책, KMS 키 정책 | 교차 계정 접근을 허용할 때 특히 중요 |
| **Permission boundary / SCP** | 조직·경계 | 명시적 Deny는 항상 승리 |

**Deny 우선 / 기본 거부(Implicit Deny)** 를 기억하면 flaws.cloud Level 6의 "읽기 권한이지만 공격에 충분" 같은 상황을 이해하기 쉽다.

## 2. S3 — 버킷·객체·ACL·정책·Block Public Access

- **버킷 이름은 글로벌 유니크** 이자 **DNS 이름** 이다. `flaws.cloud` 라는 도메인이 바로 버킷 이름이 되는 이유.
- 호스팅 리전을 모를 때:
  ```bash
  curl -I http://flaws.cloud.s3.amazonaws.com/
  # x-amz-bucket-region: us-west-2   ← 이 헤더를 본다
  ```
- **권한 부여 방식 세 가지** — 오래된 순서
  1. **ACL (Access Control List)** — 레거시. `AuthenticatedUsers` / `AllUsers` 같은 넓은 그룹이 있어 **flaws L1/L2 의 주범**.
  2. **Bucket Policy** — JSON 기반, 현대적. 리소스·조건 세밀.
  3. **IAM Identity Policy** — 사용자/역할이 가진 권한.
- **Block Public Access (BPA)** — 2018년 이후 기본 제공. 버킷/계정 레벨에서 공개 ACL·공개 정책을 차단. **지금 새로 만드는 버킷은 기본적으로 차단** 된다. flaws.cloud 는 이 기능 전에 만들어졌기에 살아 있다.
- **`--no-sign-request`** — AWS CLI 가 IAM 서명을 붙이지 않고 보내기. 익명 접근이 허용된 버킷을 조사할 때 사용.

## 3. IAM 사용자 vs 역할 vs STS 임시 자격증명

| 구분 | 자격증명 형태 | 만료 | 생성 방식 |
|------|-------------|------|-----------|
| IAM **사용자** | `AKIA...` + secret | 수동 회전 | `aws iam create-user` → create-access-key |
| IAM **역할** | 역할 자체엔 키 없음 | — | `aws iam create-role` + trust policy |
| **STS 임시 키** | `ASIA...` + secret + session token | 15분~12시간 | `sts assume-role`, EC2 역할, ECS task role, Cognito 등이 내부적으로 발급 |

핵심: **`ASIA` 로 시작하는 키 = 세션 토큰이 반드시 필요** (환경변수 `AWS_SESSION_TOKEN`). flaws L5에서 탈취한 IMDS 자격증명이 이것.

## 4. EC2 IMDS v1 vs v2

EC2 인스턴스 내부에서 `http://169.254.169.254/` 를 호출하면 해당 인스턴스의 **역할 자격증명** 을 받을 수 있다.

- **IMDSv1** — GET 한 번으로 끝. 웹앱에 SSRF 가 있으면 **외부에서 바로 자격증명 탈취**. **flaws L5 의 핵심.**
- **IMDSv2** — 토큰 기반. 먼저 PUT 으로 세션 토큰 받고, 그 토큰을 헤더로 GET. 브라우저 기반 SSRF 로는 어렵다.
  ```bash
  # IMDSv2 사용 예
  TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
  curl -H "X-aws-ec2-metadata-token: $TOKEN" \
    http://169.254.169.254/latest/meta-data/iam/security-credentials/
  ```
- 2022년 이후 **새 런치 템플릿/AMI 는 IMDSv2 강제**가 가능하다. `aws ec2 modify-instance-metadata-options --http-tokens required`.

### 자격증명 엔드포인트
```
/latest/meta-data/iam/security-credentials/<RoleName>
```
반환 JSON 예:
```json
{
  "Code" : "Success",
  "AccessKeyId" : "ASIA...",
  "SecretAccessKey" : "...",
  "Token" : "...",
  "Expiration" : "2026-04-18T02:30:00Z"
}
```

## 5. ECS Task Role 과 Task Metadata Endpoint

ECS (EC2/Fargate) 의 컨테이너는 IMDS 가 아니라 **컨테이너 전용 엔드포인트**에서 자격증명을 받는다.

- 환경변수 `AWS_CONTAINER_CREDENTIALS_RELATIVE_URI` 가 경로를 담고 있음.
- EC2 런치형: `http://169.254.170.2<경로>` 로 GET
- Fargate: 동일하게 `169.254.170.2`, SSRF 도 동일 구조로 작동 → **flaws2 Attacker L3 의 핵심**.

## 6. Lambda 와 API Gateway 기본 보안 포인트

- Lambda 함수는 자체 **실행 역할(execution role)** 을 갖는다. 환경변수로 비밀을 넣으면 `aws lambda get-function-configuration` 만으로 조회 가능 → **flaws L6 의 결정타**.
- **리소스 기반 정책** 으로 `lambda:InvokeFunctionUrl`, `apigateway:Invoke` 가 Principal `*` 로 열리면 인터넷에서 누구나 호출 가능.
- API Gateway 의 **Stage → Resource → Method** 구조를 기억. `aws apigateway get-resources --rest-api-id ...` 로 숨은 경로 탐색.

## 7. CloudTrail — 무엇이 기록되고 무엇이 안 되는가

- 기본 Management Event: AWS **제어평면(API)** 호출 기록. `StartInstances`, `AssumeRole`, `PutBucketPolicy` 등.
- **Data Event** (S3 GetObject, Lambda Invoke)는 **기본 off**. 별도 활성화 + 비용.
- Event 에 `sourceIPAddress`, `userIdentity`, `userAgent`, `requestParameters`, `errorCode` 가 포함 → flaws2 Defender 트랙이 이걸 집중적으로 씹는다.
- 로그는 S3 에 gzip + JSON 으로 떨어진다: `AWSLogs/<account>/CloudTrail/<region>/<yyyy>/<mm>/<dd>/<file>.json.gz`

```bash
# 한 줄 이벤트로 풀어보기
zcat cloudtrail.json.gz | jq -c '.Records[]'
```

## 8. EBS 스냅샷의 공개 공유

- 스냅샷에 `CreateVolumePermission = { Group: "all" }` 을 주면 **전 세계 공개**. flaws L4 가 이 실수.
- 공격자는 본인 계정에서 `create-volume --snapshot-id <공개 스냅샷>` 후 자기 EC2에 `attach-volume` → 마운트 → 내부 파일(예: `.htpasswd`, `.env`) 탈취.
- 2023년 기준 **새 스냅샷은 기본 비공개**. AWS Config 규칙 `ebs-snapshot-public-restorable-check` 으로 감시 가능.

## 9. Access Key 탐지 패턴

코드베이스·로그·깃 히스토리에서 AWS 키를 찾을 때의 정규식:

```
AKIA[0-9A-Z]{16}      # 장기 IAM 사용자 키
ASIA[0-9A-Z]{16}      # STS 임시 키
(?:^|[^A-Za-z0-9/+])  # 시크릿 40자 전후 경계
[A-Za-z0-9/+=]{40}
```

도구 추천:
- `trufflehog`, `gitleaks`, `detect-secrets` — 깃 히스토리 스캔
- AWS GuardDuty 의 `UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration` — 탈취된 EC2 역할 키가 외부에서 쓰이면 탐지

---

## ✅ 체크리스트

- [ ] S3 public 을 허용하는 두 가지 경로(ACL vs Bucket Policy) 설명 가능
- [ ] 키 prefix 로 장기/임시 자격증명 구분 가능 (`AKIA` / `ASIA`)
- [ ] IMDSv1 vs v2 차이 설명 가능
- [ ] ECS task metadata endpoint IP 기억 (`169.254.170.2`)
- [ ] CloudTrail Management Event vs Data Event 차이
- [ ] 공개 EBS 스냅샷 악용 흐름
