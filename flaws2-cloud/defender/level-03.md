# Defender Level 3 — 악의적 API 호출 패턴

> **핵심 기술**: CloudTrail event 패턴 분석 · IR 가설 수립
> **난이도**: ⭐⭐
> **본인 AWS 계정 필요**: ❌

## 🎯 목표

Level 2 에서 공격자 IP·아이덴티티를 특정했으니, 이제 **무엇을 했고, 무엇까지 접근했는가** 를 시간순으로 재구성한다. 이어지는 Athena 레벨의 밑밥이 된다.

## 🧭 공식 힌트

<details>
<summary><b>Hint 1</b></summary>

> 공격자의 행위는 대개 3단계 — **정찰(reconnaissance) → 권한 확인(capability probing) → 데이터 접근(exfiltration)**.

</details>

<details>
<summary><b>Hint 2</b></summary>

> `errorCode` 필드를 보세요. "권한 부족" 으로 실패한 호출이 많으면 공격자가 **권한 경계를 테스트** 중이라는 증거입니다.

</details>

<details>
<summary><b>Hint 3</b></summary>

> `requestParameters` / `responseElements` 에 **접근한 리소스 ARN** 이 들어 있을 때가 많습니다.

</details>

## 📚 사전 지식

- 일반 CloudTrail event 는 `errorCode` 가 없으면 성공. `AccessDenied`, `UnauthorizedOperation` 이 찍히면 실패.
- `requestParameters` 는 API 별 스키마가 다름. `GetObject` 면 `{bucketName, key}`, `Invoke` 면 `{functionName}`.
- 공격자의 **전형적 정찰 순서**: `GetCallerIdentity → ListXxx → GetXxx → Invoke/GetObject`.

## 🔍 정찰 → 🛠 풀이

### 1. 성공/실패 분포
```bash
jq -r 'select(.sourceIPAddress=="104.102.221.250")
       | [.eventName, (.errorCode // "SUCCESS")] | @tsv' /tmp/all.ndjson \
  | sort | uniq -c | sort -rn
```
예상:
```
 23 ListFunctions           SUCCESS
 15 GetFunction             SUCCESS
  8 Invoke                  AccessDenied
  5 ListBuckets             AccessDenied
  4 GetCallerIdentity       SUCCESS
```
**권한 경계 테스트** — AccessDenied 이 다양한 eventName 에 나타남.

### 2. 공격자가 건드린 Lambda 함수
```bash
jq -c 'select(.sourceIPAddress=="104.102.221.250" and .eventSource=="lambda.amazonaws.com")
       | {eventTime, eventName, fn: .requestParameters.functionName}' /tmp/all.ndjson
```
예상:
```json
{"eventTime":"2018-11-28T22:32:11Z","eventName":"GetFunction","fn":"level1"}
{"eventTime":"2018-11-28T22:32:13Z","eventName":"GetFunction","fn":"level2"}
```
`level1`, `level2` Lambda 를 GET — 소스 다운로드 성공 여부는 `errorCode` 로 확인.

### 3. 공격자가 얻은 자격증명 체인
```bash
jq -c 'select(.sourceIPAddress=="104.102.221.250" and .eventName=="GetCredentialsForIdentity")
       | {eventTime, .requestParameters, .responseElements}' /tmp/all.ndjson
```
Cognito 가 ASIA 임시 키를 발급한 시각이 나온다. 이후 이 키로 다른 API 호출이 이어진다.

### 4. 시간 순 타임라인 (미니 버전)
```bash
jq -r 'select(.sourceIPAddress=="104.102.221.250")
       | "\(.eventTime)  \(.eventName)  \(.requestParameters.functionName // .requestParameters.bucketName // "-")"' \
  /tmp/all.ndjson | sort | head -20
```
이 출력이 곧 **공격 스토리**.

### 5. "외부 공격자 외" — 정상 트래픽과 구분
AWS 내부 서비스가 호출한 것(`.sourceIPAddress | contains("amazonaws.com")`) 은 대부분 자동화. 외부 IP 중에서도 본인 팀 IP(`203.0.113.x`) 는 제외하면 남는 게 공격자.

## 🧨 취약점 원리 (방어 관점)

- **"정찰 + 반복된 AccessDenied"** 는 가장 단순한 시그니처. GuardDuty `Recon:IAMUser/*` 가 바로 이걸 잡는다.
- Lambda `GetFunction` 으로 **소스 zip URL** 을 주면, CloudTrail 에 "URL 자체"는 안 남지만 호출 시각과 주체가 남아 소급 포렌식 가능.

## 🛡 방어 대책

### ① IAM Access Analyzer — Unused access
장기간 미호출된 권한 자동 식별 → 최소권한 축소.

### ② GuardDuty finding-level 알림
`UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration.OutsideAWS` 는 **Cognito/ECS/EC2 자격증명이 외부에서 쓰일 때** 울린다.

### ③ Lambda 데이터 이벤트 활성화
기본 off 인 Lambda `Invoke` 데이터 이벤트를 켜면 **누가, 어느 함수를, 얼마나 호출** 했는지 전부 기록.

### ④ S3 버킷 정책에 `aws:SourceIp` 제한
데이터 읽기에 SourceIp 리스트 고정 → 자격증명을 훔쳐도 외부 IP 에선 못 쓴다.

### ⑤ CloudWatch Metric Filter + 알람
```
{ ($.errorCode = "AccessDenied") || ($.errorCode = "UnauthorizedOperation") }
```
5분에 10건 초과 시 SNS 로 호출 → 바로 IR 팀 전파.

## ✅ 체크리스트

- [ ] 공격자 IP 의 eventName × errorCode 분포표 작성
- [ ] 공격자가 건드린 Lambda/S3 리소스 ARN 목록 확보
- [ ] 시간순 타임라인(최소 10 이벤트) 재구성
- [ ] 본인 계정에 CloudWatch AccessDenied 알람 구성

## ⏭ 다음

[← Defender L2](level-02.md) · [Defender Level 4 →](level-04.md)
