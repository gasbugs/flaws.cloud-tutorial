# Level 2 — AuthenticatedUsers 그룹 오남용

> **URL**: http://level2-c8b217a33fcf1f839f6f1f73a00a9ae7.flaws.cloud/<br>
> **핵심 기술**: S3 ACL / AWS 전역 그룹 / IAM<br>
> **난이도**: ⭐<br>
> **본인 AWS 계정 필요**: ✅

## 🎯 목표

익명으로는 리스팅되지 않는 버킷이다. **본인의 AWS 계정** 으로 인증만 하면 리스팅이 되는데 — 이게 도대체 왜 가능한가? 그리고 다음 레벨의 서브도메인은 어디 숨어 있는가?

## 🧭 공식 힌트

<details>
<summary><b>Hint 1</b></summary>

> 이 버킷은 **어떤 AWS 사용자든** 리스팅할 수 있도록 구성되어 있습니다. 익명으로는 실패하지만, 본인이 AWS 사용자를 가지고 있다면 성공합니다.

</details>

<details>
<summary><b>Hint 2</b></summary>

> `AuthenticatedUsers` 라는 S3 ACL 그룹에 대해 검색해 보세요.

</details>

<details>
<summary><b>Hint 3</b></summary>

> `aws s3 ls` 를 `--profile <자신의 프로파일>` 과 함께 사용하세요. `--no-sign-request` 는 안 됩니다.

</details>

## 📚 사전 지식

S3 ACL 에는 네 개의 "사전 정의된 그룹" 이 있다:

| 그룹 | 의미 |
|------|------|
| `AllUsers` | 익명 포함 **누구나** (L1 에서 만난 그룹) |
| **`AuthenticatedUsers`** | **AWS 의 어떤 인증된 사용자든** (= 지구상 모든 AWS 고객) |
| `LogDelivery` | CloudFront 등 로그 배달 서비스 |
| `BucketOwner` | 버킷 소유자 |

이름이 "인증된 사용자" 라 안전해 보이지만, **AWS 가입은 무료에 가깝고 수분 안에 끝난다.** 따라서 `AuthenticatedUsers` 에 권한을 주는 것은 사실상 **전 세계 공개**다. AWS 자신도 2021 년 이 UI 에 "이 옵션을 사용하면 **모든 AWS 계정의 사용자**가 접근할 수 있습니다" 라는 경고를 추가했다.

## 🔍 정찰

익명 시도가 실패하는 것부터 확인:

```bash
aws s3 ls s3://level2-c8b217a33fcf1f839f6f1f73a00a9ae7.flaws.cloud/ \
  --no-sign-request --region us-west-2
# 결과: An error occurred (AccessDenied) when calling the ListObjectsV2 operation: Access Denied
```

본인 프로파일 준비 확인:
```bash
aws sts get-caller-identity --profile myown
# {
#   "UserId": "AIDA...",
#   "Account": "111122223333",
#   "Arn": "arn:aws:iam::111122223333:user/me"
# }
```

## 🧨 취약점 원리

이 버킷의 ACL 에는 다음과 같은 그랜트가 설정돼 있다:

```xml
<Grant>
  <Grantee xsi:type="Group">
    <URI>http://acs.amazonaws.com/groups/global/AuthenticatedUsers</URI>
  </Grantee>
  <Permission>READ</Permission>
</Grant>
```

> *URI* 가 `global/AuthenticatedUsers` 인 Grant 는 "서명된 요청을 보내는 모든 AWS 사용자" 에게 권한을 준다.

그래서 `--no-sign-request` 는 막히지만, 아무 본인 계정으로 서명만 해 주면 통과한다.

## 🛠 풀이

### 1. 본인 프로파일로 리스팅

```bash
aws s3 ls s3://level2-c8b217a33fcf1f839f6f1f73a00a9ae7.flaws.cloud/ \
  --profile myown --region us-west-2
```

예상 출력:
```
2017-02-27 10:02:15      80751 everyone.png
2017-03-03 11:47:17       1433 hint1.html
2017-03-03 11:47:17       1035 hint2.html
2017-03-03 11:47:17        765 hint3.html
2017-03-03 11:47:17       1614 index.html
2017-02-27 10:02:14         31 robots.txt
2017-02-27 10:02:14       1458 secret-e4443fc.html
```

### 2. `secret-*.html` 열기

```bash
curl -s http://level2-c8b217a33fcf1f839f6f1f73a00a9ae7.flaws.cloud/secret-e4443fc.html
```

본문에 다음 레벨 URL이 박혀 있다.

## 🚪 정답 & 다음 레벨

<details>
<summary>정답 펼치기</summary>

- 다음 레벨: **http://level3-9afd3927f195e10225021a578e6f78df.flaws.cloud/**
- 교훈: `AuthenticatedUsers` 는 "인증된 우리 팀 사용자" 를 의미하지 않는다. 이름에 속지 말고, 항상 **특정 계정 ID·역할·사용자**를 주체(Principal)로 지정하는 Bucket Policy 를 쓰자.

</details>

## 🌍 실제 세계 사례

- 2018 년 **FedEx** — 과거 인수한 Bongo 의 S3 버킷이 `AuthenticatedUsers` 읽기 허용으로 고객 여권·운전면허 스캔본 119,000 건 노출.
- 많은 CMS 플러그인의 기본 권장값이 "Authenticated" 라는 용어 때문에 오인되어 설정되곤 했다.

## 🛡 방어 대책

### ① 버킷 ACL 사용 중지 — "Bucket owner enforced" 설정
2021 년 AWS 가 추가한 **Object Ownership = BucketOwnerEnforced** 를 켜면 ACL 자체가 비활성화되고 버킷 정책만 남는다.
```bash
aws s3api put-bucket-ownership-controls \
  --bucket mybucket \
  --ownership-controls 'Rules=[{ObjectOwnership=BucketOwnerEnforced}]'
```

### ② 만약 ACL 을 유지해야 한다면 공개 그룹 그랜트 전부 제거
```bash
aws s3api get-bucket-acl --bucket mybucket  # 현재 상태 확인
aws s3api put-bucket-acl --bucket mybucket --acl private
```

### ③ 특정 계정만 허용하는 Bucket Policy 로 대체
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowPartnerAccount",
      "Effect": "Allow",
      "Principal": { "AWS": "arn:aws:iam::222233334444:root" },
      "Action": ["s3:ListBucket", "s3:GetObject"],
      "Resource": [
        "arn:aws:s3:::mybucket",
        "arn:aws:s3:::mybucket/*"
      ]
    }
  ]
}
```

### ④ Block Public Access → `IgnorePublicAcls=true`
BPA 가 `IgnorePublicAcls` 를 `true` 로 두면, 과거 설정된 `AuthenticatedUsers` 그랜트를 **무시** 한다. 신규/구 버킷 모두에 계정 레벨로 강제하자.

### ⑤ AWS Config 규칙
- `s3-bucket-acl-prohibited` — 2023 년 추가, BucketOwnerEnforced 가 아닌 버킷을 탐지.

## ✅ 체크리스트

- [ ] `--no-sign-request` 실패, `--profile myown` 성공 재현
- [ ] `AuthenticatedUsers` 그룹의 정확한 의미 설명 가능
- [ ] 본인 계정에 테스트 버킷 → `AuthenticatedUsers` 로 READ 부여 → BPA 가 어떻게 이를 차단하는지 확인
- [ ] BucketOwnerEnforced 로 변경 시 ACL 관련 API 가 전부 실패하는지 확인

## ⏭ 다음

[← Level 1](level-01.md) · [Level 3 →](level-03.md)
