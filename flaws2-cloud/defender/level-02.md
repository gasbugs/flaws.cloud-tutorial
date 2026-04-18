# Defender Level 2 — jq 로 공격자 IP·Identity 식별

> **핵심 기술**: `jq` · CloudTrail 이벤트 스키마<br>
> **난이도**: ⭐⭐<br>
> **본인 AWS 계정 필요**: ❌

## 🎯 목표

Level 1 에서 받은 로그 파일들에서 **공격자의 IP·사용자 아이덴티티·공격 시각** 을 식별한다. 이후 레벨에서 쓸 "정상 트래픽 vs 이상 트래픽" 구분 감을 기른다.

## 🧭 공식 힌트

<details>
<summary><b>Hint 1</b></summary>

> CloudTrail 이벤트는 `userIdentity.type`, `userIdentity.accessKeyId`, `sourceIPAddress`, `userAgent`, `eventName` 같은 필드를 가집니다.

</details>

<details>
<summary><b>Hint 2</b></summary>

> `jq` 의 `group_by`, `sort_by`, `| select(...)` 를 섞어 씁니다.

</details>

<details>
<summary><b>Hint 3</b></summary>

> AWS 내부 서비스 호출은 `sourceIPAddress` 가 `cognito-identity.amazonaws.com` 이나 `ec2.amazonaws.com` 같은 도메인으로 나옵니다. **IP 주소** 로 나오는 건 외부 클라이언트.

</details>

## 📚 사전 지식

모든 jq 예제는 `Records[]` 를 통째로 합쳐 파이프한다:
```bash
alias logs='gunzip -c AWSLogs/**/CloudTrail/**/*/*/*/*.json.gz | jq -c ".Records[]"'
```
또는 한 번에 스트림 처리:
```bash
find . -name '*.json.gz' -exec gunzip -c {} + | jq -c '.Records[]' > /tmp/all.ndjson
```

## 🔍 정찰 → 🛠 풀이

### 1. 발생한 모든 IP 집계 (외부 IP 만)
```bash
jq -r 'select(.sourceIPAddress | test("^[0-9]+\\.")) | .sourceIPAddress' /tmp/all.ndjson \
  | sort | uniq -c | sort -rn
```
예상 출력:
```
     27 104.102.221.250   ← 공격자 의심 (다수 호출)
      5 34.234.236.212   ← 낮은 빈도 — 기존 스캐너/봇일 수 있음
```

### 2. 의심 IP 의 이벤트 종류 확인
```bash
jq -r 'select(.sourceIPAddress=="104.102.221.250") | .eventName' /tmp/all.ndjson \
  | sort | uniq -c | sort -rn
# 17 GetObject
#  4 ListObjects
#  3 ListImages          ← ECR 이미지 목록(Attacker L2)
#  2 BatchGetImage
#  1 GetAuthorizationToken
```
공격자 패턴이 그대로 보인다: **S3 GetObject / ListObjects(비밀 파일 조회) + ECR ListImages/BatchGetImage(컨테이너 이미지 추출)**.

### 3. 공격자의 UserIdentity 추적
```bash
jq -c 'select(.sourceIPAddress=="104.102.221.250") | {eventTime, eventName, userIdentity}' \
  /tmp/all.ndjson | head -5
```
출력에 `userIdentity.type` 이 `AssumedRole`, `userIdentity.sessionContext.sessionIssuer.userName` 이 `level1` 로 나온다 — **Attacker L1 에서 Lambda 에러로 흘러나온 `level1` 역할 자격증명** 이 쓰였음을 확정.

### 4. 공격 윈도우
```bash
jq -r 'select(.sourceIPAddress=="104.102.221.250") | .eventTime' /tmp/all.ndjson \
  | sort | sed -n '1p; $p'
# 2018-11-28T22:35:00Z   (예시; 실제 값은 데이터에 따라 다름)
# 2018-11-28T23:10:00Z
```
약 30분 내의 집중 공격.

### 5. 유저 에이전트
```bash
jq -r 'select(.sourceIPAddress=="104.102.221.250") | .userAgent' /tmp/all.ndjson \
  | sort | uniq -c | sort -rn
#  75 aws-cli/1.16.19 Python/3.6.5 ...
```
`aws-cli` 임 — CLI 도구로 조사한 정황.

## 🧨 취약점 원리 (방어 관점)

정상 애플리케이션 호출은 **대부분 AWS 내부 IP / 서비스 도메인 이름** 으로 찍힌다. **공개 IP 에서 직접 sts/iam/lambda 호출** 이 갑자기 쏟아지면 거의 확실히 외부 공격.

## 🛡 방어 대책

### ① GuardDuty 활성화
Cognito 미인증 자격증명의 비정상 사용을 자동 탐지 (`UnauthorizedAccess:IAMUser/ConsoleLoginSuccess.B` 등).

### ② CloudTrail Insight 이벤트
`aws cloudtrail put-insight-selectors --trail-name org --insight-selectors '[{"InsightType":"ApiCallRateInsight"}]'` — API 호출 스파이크 자동 감지.

### ③ WAF / 서비스 컨트롤 정책으로 IP 제한
고위험 IAM action 에 `aws:SourceIp` condition 추가.

### ④ SIEM 연계
Splunk / Datadog / OpenSearch 로 CloudTrail 연동해 **대시보드에서 IP 기준 집계** 하면 이 레벨의 jq 작업이 자동화된다.

## ✅ 체크리스트

- [ ] 전체 로그를 하나의 NDJSON 으로 병합
- [ ] 외부 IP 별 이벤트 수 TOP 5 집계
- [ ] 공격자 UserIdentity · UA · 공격 윈도우 산출
- [ ] GuardDuty 가 이 공격을 어떻게 잡는지 본인 계정에서 테스트

## ⏭ 다음

[← Defender L1](level-01.md) · [Defender Level 3 →](level-03.md)
