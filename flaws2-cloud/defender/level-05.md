# Defender Level 5 — Athena 로 공격 타임라인 재구성

> **핵심 기술**: Athena SQL · IR 보고서 산출
> **난이도**: ⭐⭐⭐
> **본인 AWS 계정 필요**: ✅

## 🎯 목표

Defender 4 에서 만든 테이블을 가지고, **"이 공격의 전체 서사"** 를 한 장의 쿼리 결과로 만든다. 누가 · 언제 · 어디서 · 무엇을 · 어떻게 · 결과는 무엇이었는지를 뽑는다.

## 🧭 공식 힌트

<details>
<summary><b>Hint 1</b></summary>

> `userIdentity.arn` 중 `assumed-role/*Level1Unauth*` 같은 이름이 단서.

</details>

<details>
<summary><b>Hint 2</b></summary>

> 공격 윈도우 앞뒤 **5분 패딩** 을 잡으면 연쇄 호출(pivot) 흔적도 잡힙니다.

</details>

<details>
<summary><b>Hint 3</b></summary>

> `errorCode IS NOT NULL` 만 필터하면 **실패한 정찰** 리스트를, `errorCode IS NULL` 로 성공한 목록을 뽑습니다.

</details>

## 🔍 쿼리 레시피

### Q1. 외부 IP 별 이벤트 수 (정상/공격 일별 대조)
```sql
SELECT sourceIpAddress, COUNT(*) AS n,
       MIN(eventTime) AS first_seen, MAX(eventTime) AS last_seen
FROM flaws2_ir.cloudtrail
WHERE yyyy='2018' AND mm='11' AND dd='28'
  AND sourceIpAddress NOT LIKE '%amazonaws.com'
GROUP BY sourceIpAddress
ORDER BY n DESC;
```

### Q2. 공격자 IP 의 행동 시퀀스
```sql
SELECT eventTime, eventName, errorCode,
       regexp_extract(requestParameters, '"functionName":"([^"]+)"', 1) AS fn,
       regexp_extract(requestParameters, '"bucketName":"([^"]+)"', 1) AS bucket
FROM flaws2_ir.cloudtrail
WHERE sourceIpAddress = '104.102.221.250'
ORDER BY eventTime ASC;
```

### Q3. 실패한 호출만 — 권한 경계 탐색
```sql
SELECT eventName, COUNT(*) AS fails
FROM flaws2_ir.cloudtrail
WHERE sourceIpAddress = '104.102.221.250'
  AND errorCode IS NOT NULL
GROUP BY eventName ORDER BY fails DESC;
```

### Q4. 자격증명 체인 — Cognito 에서 발급된 세션이 이후 뭘 했는가
```sql
-- 먼저 Cognito GetCredentialsForIdentity 시각을 확인
SELECT eventTime, responseElements
FROM flaws2_ir.cloudtrail
WHERE eventName = 'GetCredentialsForIdentity'
  AND sourceIpAddress = '104.102.221.250';

-- 해당 accessKeyId(ASIA...) 로 이어진 호출 추적
SELECT eventTime, eventName, errorCode
FROM flaws2_ir.cloudtrail
WHERE userIdentity.accessKeyId = 'ASIA...추출한값'
ORDER BY eventTime;
```

### Q5. 접근한 데이터 자원 ARN
```sql
SELECT DISTINCT r.arn, r.type
FROM flaws2_ir.cloudtrail
CROSS JOIN UNNEST(resources) AS t(r)
WHERE sourceIpAddress = '104.102.221.250'
ORDER BY r.arn;
```

## 🧩 서사 조립 (요청 답안 예)

1. **2018-11-28 22:31** — 공격자 IP `104.102.221.250` 에서 `GetId` (Cognito) 호출 → Identity 생성
2. **22:31:05** — `GetCredentialsForIdentity` → ASIA 키 발급 (`assumed-role/Cognito_Level1Unauth_Role`)
3. **22:32:00** — `lambda:ListFunctions` → `level1`, `level2` 함수 식별
4. **22:32:11 / 22:32:13** — `lambda:GetFunction level1`, `level2` → 소스 zip URL 확보
5. **22:35 이후** — ECR `DescribeRepositories`, `GetRepositoryPolicy` 로 컨테이너 정찰
6. **22:38** — 공격자가 컨테이너 이미지 pull → 내부 키 발견
7. **22:41** — 내부 키로 `s3:ListAllMyBuckets` → 최종 버킷 접근

## 🛡 방어 대책 요약 (전체 트랙)

| 관측 | 방어 |
|------|------|
| Cognito Unauth role 과권한 | **최소권한 정책**, Cognito User Pool 인증 강제 |
| Lambda 소스 유출 | `lambda:GetFunction` 권한 회수, 비밀은 Secrets Manager |
| ECR 공개 레포 | `Principal: *` 금지, private 기본 |
| ECS Task Metadata SSRF | 앱 레벨 링크로컬 필터, Task Role 최소권한 |
| 로그 분석 부재 | Athena/CloudTrail Lake, GuardDuty, Metric alarm |

## ✅ 체크리스트

- [ ] Q1~Q5 전부 실행, 결과 확보
- [ ] 공격 타임라인 7~10 단계로 한 페이지에 요약
- [ ] 탈취 리소스 ARN 을 IR 보고서에 첨부
- [ ] 각 공격 단계에 대응하는 방어 대책 매핑

## 🎓 최종

👏 **flaws2.cloud Defender 트랙 완주**. flaws.cloud + flaws2.cloud 를 끝까지 따라왔다면, 이제 다음 주제로 확장하기 좋다:

- **CloudGoat** (Rhino Security Labs) — Terraform 으로 만드는 20+ 시나리오
- **pacu** — AWS 전용 공격 프레임워크 실습
- **Steampipe / PMapper** — IAM 권한 경로 시각화
- **AWS Wellarchitected — Security Pillar** 리뷰로 현업 체크리스트화

## ⏭ 마무리

[← Defender L4](level-04.md) · [최상위 README](../../README.md)
