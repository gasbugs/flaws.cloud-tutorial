# Level 6 — SecurityAudit 류 읽기 권한 남용

> **진입 URL**: http://level6-cc4c404a8a8b876167f5e70a7d8c9880.flaws.cloud/ddcc78ff/<br>
> **핵심 기술**: IAM 정책 해독 / Lambda / API Gateway<br>
> **난이도**: ⭐⭐⭐<br>
> **본인 AWS 계정 필요**: ❌ (문제에서 access key 제공)

## 🎯 목표

사이트가 **직접 자격증명을 준다** — "어디까지 할 수 있는지 한 번 봐보라" 는 뉘앙스로. 이 키에는 **광범위한 읽기 정책 (예전 `SecurityAudit`, 현재 `MySecurityAudit`)** 이 붙어 있다. 이 정책만으로도 숨어 있는 Lambda 함수를 발견하고, 비공개 API Gateway URL 을 알아내 최종 플래그 페이지에 도달한다.

## 🧭 공식 힌트

사이트가 바로 아래 자격증명을 제공한다 — **사이트는 주기적으로 키를 로테이션**하므로 반드시 **현재 페이지에서 최신 값을 복사**해야 한다:

```bash
# 항상 최신 키는 이 URL 에 접속해서 복사
open http://level6-cc4c404a8a8b876167f5e70a7d8c9880.flaws.cloud/ddcc78ff/
# 페이지 하단에 표시:
#   Access key ID:  AKIA...OBGA
#   Secret:         S2Ipym...
```

> ⚠️ 본 문서에 **Secret 전체를 붙여넣지 않는 이유** — GitHub secret scanning 을 통과하도록. 실제 값은 페이지에서 받아 로컬에만 저장하세요.

<details>
<summary><b>Hint 1</b></summary>

> 이 사용자에게 어떤 정책이 붙어 있는지 보세요. IAM 관리형 정책은 **이름만으로도 정보** 입니다.

</details>

<details>
<summary><b>Hint 2</b></summary>

> "보안 감사" 류 정책은 읽기 권한입니다. 그런데 "읽기" 만으로도 Lambda, API Gateway, 누가 누구에게 호출 권한을 주었는지 다 들여다볼 수 있습니다.

</details>

<details>
<summary><b>Hint 3</b></summary>

> Lambda 함수의 **리소스 기반 정책** 과 API Gateway 의 **Stage / Resource** 구조를 합치면 공개 URL 이 나옵니다.

</details>

## 📚 사전 지식

- IAM 정책 `SecurityAudit` (혹은 이를 모방한 커스텀 `MySecurityAudit`) 은 리소스의 **메타데이터**를 전부 읽게 해 준다 (list·get·describe 류). 하지만 "데이터" 자체는 못 본다.
- 그러나 **구성 정보 자체가 비밀** 일 수 있다 — 예컨대 Lambda 의 환경변수, API Gateway 의 비공개 엔드포인트 경로.
- Lambda 에는 **리소스 기반 정책(Permissions)** 이 있어, 누가(API Gateway 등) 이 함수를 호출할 수 있는지가 기록된다.
- API Gateway URL 형식: `https://<api-id>.execute-api.<region>.amazonaws.com/<stage>/<resource>`

## 🔍 정찰

### 1. 자격증명 등록 (페이지에서 복사한 키 사용)
```bash
aws configure --profile level6
# AWS Access Key ID [None]: AKIA...OBGA            # 페이지의 Access key ID
# AWS Secret Access Key [None]: S2Ipym...          # 페이지의 Secret
# Default region name [None]: us-west-2
# Default output format [None]: json
```

### 2. 나는 누구인가
```bash
aws sts get-caller-identity --profile level6
```
예상:
```json
{
  "UserId": "AIDA...",
  "Account": "975426262029",
  "Arn": "arn:aws:iam::975426262029:user/Level6"
}
```

### 3. 내 정책 조회
```bash
aws iam list-attached-user-policies --user-name Level6 --profile level6
```
예상 (정책명은 시점에 따라 `SecurityAudit` 또는 `MySecurityAudit` 이 붙을 수 있음):
```json
{
  "AttachedPolicies": [
    { "PolicyName": "MySecurityAudit",   "PolicyArn": "arn:aws:iam::975426262029:policy/MySecurityAudit" },
    { "PolicyName": "list_apigateways",  "PolicyArn": "arn:aws:iam::975426262029:policy/list_apigateways" }
  ]
}
```

`list_apigateways` 라는 **맞춤형 정책** 이 붙어 있다. 이름이 너무 친절하다.
```bash
POLICY_ARN=arn:aws:iam::975426262029:policy/list_apigateways
DEFAULT_V=$(aws iam get-policy --policy-arn $POLICY_ARN --profile level6 \
              --query 'Policy.DefaultVersionId' --output text)
aws iam get-policy-version --policy-arn $POLICY_ARN --version-id $DEFAULT_V --profile level6
```
정책 본문:
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["apigateway:GET"],
    "Resource": "arn:aws:apigateway:us-west-2::/restapis/*"
  }]
}
```

## 🧨 취약점 원리

"SecurityAudit(또는 유사)은 단지 읽기 아닌가요?" — 맞다. 하지만:
- `lambda:GetFunction*`, `lambda:ListFunctions`, `lambda:GetPolicy` 가 포함된다.
- `apigateway:GET` 을 추가로 받았다. 이것이면 **REST API 의 모든 경로**를 다 본다.

즉 **"조회만 하는 권한"** 으로도 비공개 API 경로를 식별할 수 있다. 숨긴다고 안전해지는 게 아니다 ("Security through obscurity" 반례).

## 🛠 풀이

### 1. Lambda 함수 목록
```bash
aws lambda list-functions --profile level6 --region us-west-2 \
  | jq '.Functions[] | {FunctionName, FunctionArn}'
```
결과:
```json
{
  "FunctionName": "Level6",
  "FunctionArn": "arn:aws:lambda:us-west-2:975426262029:function:Level6"
}
```

### 2. Lambda 정책(누가 호출 가능한가) 확인
```bash
aws lambda get-policy --function-name Level6 --profile level6 --region us-west-2 \
  | jq -r '.Policy | fromjson'
```
```json
{
  "Version": "2012-10-17",
  "Id": "default",
  "Statement": [{
    "Sid": "904610a93f593b76ad66ed6ed82c0a8b",
    "Effect": "Allow",
    "Principal": { "Service": "apigateway.amazonaws.com" },
    "Action": "lambda:InvokeFunction",
    "Resource": "arn:aws:lambda:us-west-2:975426262029:function:Level6",
    "Condition": {
      "ArnLike": {
        "AWS:SourceArn": "arn:aws:execute-api:us-west-2:975426262029:s33ppypa75/*/GET/level6"
      }
    }
  }]
}
```
**API Gateway ID = `s33ppypa75`**, **경로 = `/level6`**, **메서드 = GET** 가 한 번에 드러났다.

### 3. API Gateway 의 Stage 확인
```bash
aws apigateway get-stages --rest-api-id s33ppypa75 --profile level6 --region us-west-2 \
  | jq '.item[].stageName'
# "Prod"
```

### 4. 최종 URL 조합 & 방문
```bash
curl -s https://s33ppypa75.execute-api.us-west-2.amazonaws.com/Prod/level6
# "Go to http://theend-797237e8ada164bf9f12cebf93b282cf.flaws.cloud/d730aa2b/"
```

## 🚪 정답 & 완주

<details>
<summary>정답 펼치기</summary>

- API URL: **https://s33ppypa75.execute-api.us-west-2.amazonaws.com/Prod/level6**
- 최종 페이지: **http://theend-797237e8ada164bf9f12cebf93b282cf.flaws.cloud/d730aa2b/**
- 교훈:
  1. **"읽기 전용" 정책도 민감 정보의 출처** 가 될 수 있다.
  2. **비공개 URL = 보안 아님.** 인증/인가 계층을 반드시 추가한다.
  3. **리소스 기반 정책** 은 식별자(ARN) 를 포함하므로, 그것 자체가 공격자에게 힌트.

</details>

🎉 **flaws.cloud 완주!** 다음은 [flaws2.cloud](../flaws2-cloud/README.md) 로.

## 🌍 실제 세계 사례

- 2021 년 한 SaaS 가 SecurityAudit 을 CI 사용자에게 붙여 둔 덕에, 침입자가 **리소스 기반 정책을 전부 덤프** 하며 조직 내부 구조를 파악 → 측면 이동에 성공.
- 많은 "비공개" API Gateway 는 사실 `aws apigateway get-resources` 만으로 전부 노출된다.

## 🛡 방어 대책

### ① 최소권한 — SecurityAudit 을 사용자에게 직접 붙이지 말 것
SecurityAudit 은 **보안 감사 전용 롤** 에만 부착하고, 사람 사용자는 `AssumeRole` 로 필요한 시간만 받는다.

### ② Lambda/API Gateway 는 인증 계층과 함께
- `API Gateway + Cognito User Pools` 또는 `API Gateway + IAM Authorization`
- Lambda URL 기능을 사용할 때도 `AuthType=AWS_IAM`
- 단순 공개가 필요하면 **WAF 규칙**으로 레이트 리미트/지리 제한 추가.

### ③ CloudTrail + GuardDuty 로 정찰 탐지
`GetPolicy`, `ListFunctions`, `GetPolicyVersion` 등이 **짧은 시간에 대량** 으로 나온 사용자는 정찰 의심. GuardDuty 의 `Recon:IAMUser/*` 시그니처가 이를 잡는다.

### ④ IAM Access Analyzer
- 외부 Principal 이 접근 가능한 Lambda/역할을 자동 탐지.
- `Unused access` 분석으로 장기 미사용 정책을 정리해 공격면 축소.

### ⑤ API Gateway 리소스 정책으로 IP 제한
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Deny",
    "Principal": "*",
    "Action": "execute-api:Invoke",
    "Resource": "execute-api:/*",
    "Condition": {
      "NotIpAddress": { "aws:SourceIp": ["203.0.113.0/24"] }
    }
  }]
}
```

## ✅ 체크리스트

- [ ] 진입 URL `/ddcc78ff/` 에서 최신 Access key ID/Secret 복사
- [ ] `list-attached-user-policies` 로 Level6 사용자 권한 확인
- [ ] `lambda:GetPolicy` 출력에서 API Gateway ID 식별
- [ ] `apigateway:GET` 으로 Stage/Resource 재조립 재현
- [ ] 최종 `theend-...flaws.cloud/d730aa2b/` 도달
- [ ] 본인 계정에서 "SecurityAudit 만 가진 사용자" 를 만들고 어디까지 들여다볼 수 있는지 실험
- [ ] 본인 Lambda URL / API Gateway 에 IAM/Cognito 인증을 덧붙이기

## 🎓 총정리

flaws.cloud 6개 레벨은 "AWS 의 기본값이 왜 지금 모습이 됐는가" 의 역사다:

| Level | 2017 당시 함정 | 2026 현재 기본 방어 |
|------|----------------|---------------------|
| 1 | S3 AllUsers ACL | Block Public Access 기본 on |
| 2 | AuthenticatedUsers ACL | BucketOwnerEnforced (ACL 비활성) |
| 3 | .git 공개 | Secret scanning (GitHub) |
| 4 | 공개 EBS 스냅샷 | 스냅샷 기본 비공개 |
| 5 | IMDSv1 SSRF | IMDSv2 강제 가능 |
| 6 | 광범위 읽기 권한 | Access Analyzer / 서비스 제어 정책 |

## ⏭ 다음

[← Level 5](level-05.md) · [flaws2.cloud 시작 →](../flaws2-cloud/README.md)
