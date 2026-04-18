# Defender Level 4 — Athena 환경 구성

> **핵심 기술**: Amazon Athena · Glue 스키마 · 파티셔닝<br>
> **난이도**: ⭐⭐<br>
> **본인 AWS 계정 필요**: ✅ (Athena 쿼리 비용 발생 가능 — 센트 단위)

## 🎯 목표

지금까지 jq 로 돌리던 로그 분석을 **SQL 로** 바꾼다. CloudTrail 로그용 Athena 외부 테이블을 만들고 간단한 쿼리 한 줄이 동작하는 데까지가 이 레벨의 목표.

## 🧭 공식 힌트

<details>
<summary><b>Hint 1</b></summary>

> Athena 는 S3 에 있는 데이터를 **그대로 SQL 로** 쿼리합니다. 데이터 이동 없음.

</details>

<details>
<summary><b>Hint 2</b></summary>

> CloudTrail 로그 전용 **`org.openx.data.jsonserde.JsonSerDe`** 를 쓰는 DDL 이 있습니다. 매번 작성하지 말고 [AWS 공식 DDL](https://docs.aws.amazon.com/athena/latest/ug/cloudtrail-logs.html) 을 붙여 쓰세요.

</details>

<details>
<summary><b>Hint 3</b></summary>

> 쿼리 결과는 자기 소유 S3 버킷에 저장됩니다. **결과 버킷** 을 미리 지정해야 첫 쿼리가 실행됩니다.

</details>

## 📚 사전 지식

- Athena 는 **Presto/Trino 기반**. 내부적으로 Glue Data Catalog 에 스키마 등록.
- CloudTrail JSON 은 **배열(Records)** 한 개가 한 파일에 들어 있어 Athena JSON SerDe 가 파싱해 준다.
- 스캔한 **데이터 용량 기준 과금** (약 $5/TB). 파티셔닝/컬럼 프루닝으로 비용 최소화.

## 🔍 환경 준비

### 1. 결과 버킷 생성 (본인 계정)
```bash
aws s3 mb s3://my-athena-results-$(date +%s) --region us-east-1
```
Athena 콘솔 → Settings → Query result location 에 입력.

### 2. (선택) 공격 로그 버킷 복제
flaws2-logs 의 로그를 본인 계정 버킷으로 복사하면 **같은 계정 내** 에서 테스트 가능.
```bash
aws s3 sync s3://flaws2-logs/AWSLogs/ s3://my-flaws2-logs/AWSLogs/ --no-sign-request
```

## 🛠 풀이 (Athena 콘솔 or CLI)

### 1. 데이터베이스 생성
```sql
CREATE DATABASE IF NOT EXISTS flaws2_ir;
```

### 2. CloudTrail 외부 테이블 DDL
```sql
CREATE EXTERNAL TABLE IF NOT EXISTS flaws2_ir.cloudtrail (
  eventVersion STRING,
  userIdentity STRUCT<
    type: STRING,
    principalId: STRING,
    arn: STRING,
    accountId: STRING,
    invokedBy: STRING,
    accessKeyId: STRING,
    userName: STRING,
    sessionContext: STRUCT<
      attributes: STRUCT<mfaAuthenticated: STRING, creationDate: STRING>,
      sessionIssuer: STRUCT<type: STRING, principalId: STRING, arn: STRING, accountId: STRING, userName: STRING>
    >
  >,
  eventTime STRING,
  eventSource STRING,
  eventName STRING,
  awsRegion STRING,
  sourceIpAddress STRING,
  userAgent STRING,
  errorCode STRING,
  errorMessage STRING,
  requestParameters STRING,
  responseElements STRING,
  additionalEventData STRING,
  requestId STRING,
  eventId STRING,
  resources ARRAY<STRUCT<arn: STRING, accountId: STRING, type: STRING>>,
  eventType STRING,
  apiVersion STRING,
  readOnly STRING,
  recipientAccountId STRING,
  serviceEventDetails STRING,
  sharedEventId STRING,
  vpcEndpointId STRING
)
PARTITIONED BY (region STRING, yyyy STRING, mm STRING, dd STRING)
ROW FORMAT SERDE 'org.openx.data.jsonserde.JsonSerDe'
STORED AS INPUTFORMAT 'com.amazon.emr.cloudtrail.CloudTrailInputFormat'
OUTPUTFORMAT 'org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat'
LOCATION 's3://my-flaws2-logs/AWSLogs/653711331788/CloudTrail/';
```

### 3. 파티션 로딩
```sql
ALTER TABLE flaws2_ir.cloudtrail
ADD PARTITION (region='us-east-1', yyyy='2018', mm='11', dd='28')
  LOCATION 's3://my-flaws2-logs/AWSLogs/653711331788/CloudTrail/us-east-1/2018/11/28/';
```
또는:
```sql
MSCK REPAIR TABLE flaws2_ir.cloudtrail;
```
(파티션이 많을 때는 **partition projection** 쓰는 것을 권장)

### 4. 첫 쿼리
```sql
SELECT eventName, COUNT(*) AS n
FROM flaws2_ir.cloudtrail
WHERE yyyy='2018' AND mm='11' AND dd='28'
GROUP BY eventName
ORDER BY n DESC
LIMIT 20;
```
결과가 나오면 환경 구성 완료.

## 🧨 취약점 원리 (방어 관점)

- 로그가 있어도 **쿼리 가능 상태**로 두지 않으면 IR 때 속수무책.
- Athena / OpenSearch / BigQuery 로 **즉시 쿼리 가능** 한 상태가 보안 운영의 성숙도 지표.

## 🛡 방어 대책

### ① Partition Projection
```sql
TBLPROPERTIES (
  'projection.enabled'='true',
  'projection.region.type'='enum', 'projection.region.values'='us-east-1,us-west-2',
  'projection.yyyy.type'='integer', 'projection.yyyy.range'='2020,2030',
  ...
)
```
`MSCK REPAIR` 없이 자동 파티션 → 스캔 비용·관리 감소.

### ② 컬럼 필터링
쿼리 비용은 **스캔량 × 단가**. `SELECT *` 금지, 필요한 컬럼만.

### ③ CloudTrail Lake (2022+ 정식)
CloudTrail 자체가 쿼리 기능 제공. Athena 를 별도로 구성하기 귀찮다면 CloudTrail Lake 만으로 대부분 해결.

### ④ Organizations 통합 테일
Organization Trail 로 전 계정 로그를 한 버킷에 통합 → 한 개 Athena 테이블로 전 계정 쿼리.

## ✅ 체크리스트

- [ ] Athena 쿼리 결과 버킷 지정
- [ ] CloudTrail 외부 테이블 DDL 실행
- [ ] 파티션 하나 이상 로드
- [ ] `GROUP BY eventName` 쿼리 결과 확인

## ⏭ 다음

[← Defender L3](level-03.md) · [Defender Level 5 →](level-05.md)
