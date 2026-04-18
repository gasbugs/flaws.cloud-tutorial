# 사전 준비

flaws.cloud / flaws2.cloud 실습에 필요한 도구와 계정 요건을 정리합니다. 모든 레벨은 **본인 돈이 나갈 일이 없지만**, 일부 레벨은 본인의 AWS 계정이 있어야 진행할 수 있습니다.

## 🎯 필수 도구

| 도구 | 용도 | 설치 (macOS/Homebrew 기준) |
|------|------|---------------------------|
| `awscli` v2 | AWS API 호출 | `brew install awscli` |
| `jq` | CloudTrail JSON 분석 (Defender) | `brew install jq` |
| `git` | Level 3 `.git` 분석 | 기본 탑재 |
| `curl` / `wget` | SSRF, S3 직접 요청 | 기본 탑재 |
| `docker` | flaws2 Attacker Level 2 (ECR 이미지 pull) | `brew install --cask docker` 또는 OrbStack |

### AWS CLI 버전 확인
```bash
aws --version
# 예: aws-cli/2.15.0 Python/3.12 ...
```
v1 도 대부분 동작하지만, **IMDSv2 관련 일부 기본값**이 다르므로 이 튜토리얼은 v2 기준입니다.

## 👤 AWS 계정 필요 여부

| 레벨 | 본인 AWS 계정 필요? | 이유 |
|------|-------------------|------|
| flaws L1 | ❌ | `--no-sign-request` 로 익명 호출 |
| flaws L2 | ✅ | "AuthenticatedUsers" 그룹은 **AWS 의 어떤 인증된 사용자든** 포함 — 본인 자격증명 필요 |
| flaws L3 | ❌ (읽기) / ✅ (획득 키 사용) | 버킷 자체는 공개, 이후 획득한 `flaws` 키로 다음 단계 |
| flaws L4 | ✅ | `describe-snapshots`, `create-volume`, `attach-volume` 호출 필요 (비용 매우 적음, 정리 필요) |
| flaws L5 | ❌ | 웹 프록시로 SSRF, 자격증명은 임시 키 획득 |
| flaws L6 | ❌ | 문제에서 access key 를 제공 |
| flaws2 Attacker 1 | ❌ | 퍼블릭 API 호출만 |
| flaws2 Attacker 2 | ❌ (Docker 만) | Public ECR pull |
| flaws2 Attacker 3 | ❌ | 웹 SSRF |
| flaws2 Defender 1~5 | ⚠️ 권장 | Level 4 의 Athena 실습은 본인 계정에서 수행 (적은 스캔 비용 발생 가능) |

> 💡 **팁** — AWS 프리티어 계정을 새로 만들고 이 실습만 해도 요금이 거의 발생하지 않습니다. 실습 후에는 생성한 스냅샷·볼륨·Athena 결과 버킷을 삭제하세요.

## 🔧 AWS CLI 프로파일 설정

이 튜토리얼은 실습용 프로파일을 **분리**하는 것을 권장합니다.

```bash
# 본인 계정 프로파일 (L2/L4 용)
aws configure --profile myown
# AWS Access Key ID: <본인 키>
# AWS Secret Access Key: <본인 시크릿>
# Default region: us-west-2   # flaws.cloud 는 us-west-2 (Oregon)
# Default output: json
```

각 레벨에서 요구되는 별도 프로파일(예: `flaws`, `level6`)은 해당 레벨 문서에서 `aws configure --profile <이름>` 으로 만들도록 안내합니다.

## 🌐 리전 주의

`flaws.cloud` / `flaws2.cloud` 의 모든 AWS 리소스는 **us-west-2 (Oregon)** 에 있습니다. CLI 명령에 `--region us-west-2` 를 빠뜨리면 엉뚱한 리전에서 빈 결과가 나와 헤맵니다.

## 🛡 윤리적 경계

- 여기서 다루는 S3 버킷·EBS 스냅샷·IAM 사용자·Lambda 함수는 **전부 실습용으로 공개된** 리소스입니다.
- 임의의 회사 도메인에 같은 기법을 시도하면 **현행법상 불법**입니다(정보통신망법 등).
- 본인이 소유하거나 **서면으로 허가받은** 시스템에만 사용하세요.

## ✅ 체크리스트

- [ ] `aws --version` 출력 확인
- [ ] `aws sts get-caller-identity --profile myown` 성공
- [ ] `jq --version`, `git --version`, `curl --version` 확인
- [ ] Docker Desktop / OrbStack 기동 확인 (L2 용)
- [ ] 이 저장소를 로컬에 clone 또는 fork
