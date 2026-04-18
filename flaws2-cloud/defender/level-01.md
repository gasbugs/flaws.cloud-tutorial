# Defender Level 1 — CloudTrail 로그 확보

> **URL**: http://flaws2.cloud/defender.htm<br>
> **핵심 기술**: CloudTrail 로그 S3 저장소 구조 · `aws s3 sync`<br>
> **난이도**: ⭐<br>
> **본인 AWS 계정 필요**: ❌ (읽기만)

## 🎯 목표

당신은 이제 **피해자 쪽 IR 담당자** 역할이다. Attacker 트랙에서 벌어진 사건의 **CloudTrail 로그** 가 S3 버킷에 남아 있다(공개됨 — 학습용). 이 버킷 이름을 찾아 전체 로그를 로컬로 내려받는다.

## 🧭 공식 힌트

<details>
<summary><b>Hint 1</b></summary>

> CloudTrail 은 기본적으로 **JSON gzip** 을 S3 에 떨어뜨립니다. 경로는 `AWSLogs/<account>/CloudTrail/<region>/<yyyy>/<mm>/<dd>/`.

</details>

<details>
<summary><b>Hint 2</b></summary>

> 힌트 페이지에서 **버킷 이름** 을 주거나, 공격받은 계정 ID 로 공개된 버킷을 추측할 수 있습니다.

</details>

<details>
<summary><b>Hint 3</b></summary>

> `aws s3 sync s3://<버킷>/ ./logs/ --no-sign-request` 로 전체 로그 다운로드.

</details>

## 📚 사전 지식

- CloudTrail 로그 경로 규약:
  ```
  s3://<bucket>/AWSLogs/<Account-ID>/CloudTrail/<region>/<yyyy>/<mm>/<dd>/
     <AccountId>_CloudTrail_<region>_<timestamp>_<RandomId>.json.gz
  ```
- 각 파일은 gzip 으로 압축된 **JSON 객체**, 내부에 `Records[]` 배열.
- 자세한 구조는 [primer §7](../../docs/aws-security-primer.md#7-cloudtrail--무엇이-기록되고-무엇이-안-되는가).

## 🔍 정찰

flaws2 의 힌트 페이지 또는 Attacker 트랙에서 얻은 정보로 버킷 이름을 찾는다:
```
flaws2-logs
```

## 🧨 취약점 원리 (방어 관점)

- 공격자 관점: 피해자의 CloudTrail 버킷이 공개였다면 **자기 자취를 먼저 지우러** 올 수 있다. 로그 버킷은 **분리된 보안 계정** + **Object Lock** 으로 보호해야 한다.
- 방어자 관점: **로그가 없으면 IR 도 없다.** flaws2 는 이 과정을 의도적으로 쉽게 만들었지만, 실제 운영 환경에서는 "다중 계정 아카이브" 가 필수.

## 🛠 풀이

### 1. 버킷 리스팅
```bash
aws s3 ls s3://flaws2-logs/ --no-sign-request --region us-east-1
```
`AWSLogs/653711331788/CloudTrail/us-east-1/...` 구조 확인.

### 2. 전체 다운로드
```bash
mkdir -p /tmp/flaws2-ir && cd /tmp/flaws2-ir
aws s3 sync s3://flaws2-logs/ . --no-sign-request --region us-east-1
```

### 3. 파일 수와 용량 확인
```bash
find . -name '*.json.gz' | wc -l
du -sh .
```

### 4. 한 건만 먼저 풀어서 내용 엿보기
```bash
gunzip -c AWSLogs/653711331788/CloudTrail/us-east-1/2018/*/*/*.json.gz \
  | jq -c '.Records[0]'
```
샘플 이벤트 하나에 `eventTime`, `eventName`, `userIdentity`, `sourceIPAddress` 등이 있다.

### 5. 날짜 범위 식별
```bash
find . -name '*.json.gz' -printf '%f\n' \
  | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | sort -u
```
공격 전후 일자를 파악.

## 🚪 정답 & 다음 레벨

<details>
<summary>정답 펼치기</summary>

- 버킷: **`flaws2-logs`**
- 로그 전체 확보 완료 — Defender Level 2 에서 jq 분석 시작.

</details>

## 🌍 실제 세계 사례

- 많은 실제 사고가 **로그 보존 실패** 로 원인 불명으로 종결된다. "CloudTrail 을 계정 내 같은 버킷에 쌓아 놓고, 공격자가 그 버킷을 지움" 은 교과서적 실수.

## 🛡 방어 대책

### ① 다중 계정 아카이브
- **Organizations** 의 Log Archive 계정(분리된 AWS 계정)에 모든 멤버 계정의 CloudTrail 을 집약.
- 해당 계정은 **최소 소수의 사람** 만 접근. 프로덕션 관리자는 읽기 전용.

### ② S3 Object Lock (Governance / Compliance 모드)
```bash
aws s3api put-object-lock-configuration --bucket logs-archive \
  --object-lock-configuration '{"ObjectLockEnabled":"Enabled","Rule":{"DefaultRetention":{"Mode":"COMPLIANCE","Days":365}}}'
```
공격자가 키를 얻어도 **365일 동안 삭제 불가**.

### ③ KMS CMK 로 기본 암호화 + 교차계정 키 사용
공격 계정에서 키 정책에 없으면 **복호화 불가** → 로그 탈취도 실패.

### ④ CloudTrail 무결성 검증 (Digest files)
```bash
aws cloudtrail validate-logs --trail-arn arn:aws:cloudtrail:...  \
  --start-time 2026-04-01T00:00:00Z
```
해시 체인으로 변조 감지.

### ⑤ MFA Delete / Versioning
로그 버킷 `s3api put-bucket-versioning ... --mfa-delete Enabled`.

## ✅ 체크리스트

- [ ] `aws s3 sync` 로 전체 로그 수신
- [ ] 한 건 gunzip + jq 로 필드 파악
- [ ] 공격 추정 날짜 범위 식별
- [ ] 본인 계정에 Organizations/Object Lock 기반 로그 아카이브 구성 계획

## ⏭ 다음

[Defender Level 2 →](level-02.md)
