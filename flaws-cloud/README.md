# flaws.cloud — AWS 오설정 6선

[flaws.cloud](http://flaws.cloud/) 는 Scott Piper 가 2017 년에 공개한 **브라우저만으로 시작할 수 있는** AWS 보안 CTF 다. 6 단계로 구성되며, 각 단계의 정답은 **다음 단계의 서브도메인** 이다. 공격자가 아무 정보 없이 도메인 하나만으로 어디까지 뚫고 들어갈 수 있는지 체험하게 한다.

> 🚪 **시작 지점**: http://flaws.cloud/

## 📊 레벨 요약

| # | 레벨 | 핵심 취약점 | 필요한 도구 | 본인 AWS 계정 필요? | 난이도 |
|---|------|-------------|-------------|---------------------|--------|
| [Level 1](level-01.md) | [flaws.cloud](http://flaws.cloud/) | S3 버킷 공개 리스팅 (`AllUsers`) | `aws cli`, `curl` | ❌ | ⭐ |
| [Level 2](level-02.md) | `level2-...flaws.cloud` | AuthenticatedUsers 그룹 리스팅 | `aws cli` (본인 프로파일) | ✅ | ⭐ |
| [Level 3](level-03.md) | `level3-...flaws.cloud` | 공개 `.git` 디렉터리에서 AKIA 키 복원 | `git`, `aws cli` | ❌ (키 획득 후 사용) | ⭐⭐ |
| [Level 4](level-04.md) | `level4-...flaws.cloud` | 공개 EBS 스냅샷 마운트 → `.htpasswd` | `aws ec2`, mount | ✅ | ⭐⭐⭐ |
| [Level 5](level-05.md) | `level5-...flaws.cloud` | `/proxy/` SSRF → IMDSv1 역할 자격증명 | `curl`, `aws cli` | ❌ | ⭐⭐ |
| [Level 6](level-06.md) | `level6-...flaws.cloud` | SecurityAudit 읽기권한 남용 → Lambda URL | `aws iam`, `aws lambda` | ❌ (문제에서 키 제공) | ⭐⭐⭐ |

## 🧭 학습 순서

1. [docs/00-prerequisites.md](../docs/00-prerequisites.md) 로 AWS CLI, jq, git 준비 확인
2. [docs/aws-security-primer.md](../docs/aws-security-primer.md) 의 관련 섹션 먼저 훑기
3. **각 레벨 문서의 `🧭 공식 힌트` 까지만 읽고 10~20 분 스스로 시도**
4. 막히면 `🛠 풀이` 섹션 열기. 재현 후 `🛡 방어 대책` 정독.

## 🌍 왜 이걸 배우나

- 2017 년 Accenture, 2019 년 Capital One, 2020 년 Twilio 등 수많은 실사건이 여기 다루는 **S3 공개 버킷·IMDS SSRF·과도한 IAM 권한** 패턴을 그대로 따른다.
- flaws.cloud 는 **AWS 에서 "기본값이 변한" 순간들** 을 기록한 살아 있는 교과서이다. Block Public Access(2018), IMDSv2(2019), S3 소유권 관리(2021), 스냅샷 기본 비공개(2023) 등 — 왜 이 기능들이 생겼는지가 6 단계에 녹아 있다.

## 📎 공식 사이트의 힌트 구조

사이트에서 각 레벨을 열면 **세 단계 힌트** 를 접힌 채로 제공한다:
- **Hint 1** — 아주 가벼운 암시 ("이 페이지의 URL 을 보세요")
- **Hint 2** — 필요한 AWS 서비스 이름
- **Hint 3** — 거의 풀이에 가까운 힌트
- **Answer** — 단계의 정답과 교훈

이 저장소의 각 `level-NN.md` 파일은 동일한 4 단계 힌트 → 풀이 → 방어 구조를 **한국어로** 제공한다.

## ⏭ 다음 코스

flaws.cloud 를 완주했다면 [flaws2.cloud](../flaws2-cloud/README.md) 에서 **Lambda · ECR · ECS** 환경의 서버리스/컨테이너 공격과, **CloudTrail · jq · Athena** 를 사용한 방어 분석으로 이어간다.
