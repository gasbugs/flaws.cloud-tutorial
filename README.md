# flaws.cloud / flaws2.cloud 한국어 튜토리얼

[flaws.cloud](http://flaws.cloud/) 와 [flaws2.cloud](http://flaws2.cloud/) 는 Scott Piper(SummitRoute)가 만든 **AWS 보안 학습용 CTF** 입니다. 이 저장소는 두 CTF 의 **모든 레벨을 한국어로 매우 상세하게** 정리한 워크스루이자 튜토리얼입니다. 단순 정답 공개가 아니라 **왜 이런 오설정이 위험한가, 어떻게 공격자가 발견하는가, 어떻게 막는가** 를 함께 설명합니다.

> ⚠️ **윤리 안내** — 본 자료는 Scott Piper 가 학습용으로 공개한 `flaws.cloud` / `flaws2.cloud` 리소스에 한해 실습합니다. 여기에 나오는 명령을 **타인의 AWS 계정/리소스에 시도하지 마세요.** 이는 컴퓨터 네트워크 침입에 해당합니다.

---

## 📚 목차

### 0. 시작 전에
- [사전 준비](docs/00-prerequisites.md) — AWS CLI·jq·git 설치, 계정 없이도 실습 가능한 레벨 구분
- [AWS 보안 primer](docs/aws-security-primer.md) — S3·IAM·IMDS·CloudTrail·Lambda·ECS 핵심 개념 요약

### 1부. [flaws.cloud](flaws-cloud/README.md) — AWS 오설정 6선
| # | 주제 | 핵심 기술 |
|---|------|-----------|
| [Level 1](flaws-cloud/level-01.md) | S3 버킷 공개 리스팅 | S3, Route 53 |
| [Level 2](flaws-cloud/level-02.md) | AuthenticatedUsers 권한 오남용 | S3 ACL, IAM |
| [Level 3](flaws-cloud/level-03.md) | .git 히스토리에서 AWS 키 복원 | S3, git, Access Key |
| [Level 4](flaws-cloud/level-04.md) | 공개 EBS 스냅샷 | EC2, EBS, snapshot |
| [Level 5](flaws-cloud/level-05.md) | IMDSv1 SSRF 로 EC2 역할 자격증명 탈취 | SSRF, IMDS, STS |
| [Level 6](flaws-cloud/level-06.md) | SecurityAudit 읽기 권한 남용 | IAM, Lambda, API Gateway |

### 2부. [flaws2.cloud](flaws2-cloud/README.md) — 서버리스/컨테이너 & IR
- **Attacker 트랙** — 서버리스(Lambda)·컨테이너(ECR/ECS) 공격 체험
  - [Attacker Level 1](flaws2-cloud/attacker/level-01.md) · Lambda PIN 검증 우회
  - [Attacker Level 2](flaws2-cloud/attacker/level-02.md) · ECR 공개 이미지 속 자격증명
  - [Attacker Level 3](flaws2-cloud/attacker/level-03.md) · ECS Task Metadata SSRF
- **Defender 트랙** — 공격자가 남긴 CloudTrail 로그로 사건 조사
  - [Defender Level 1](flaws2-cloud/defender/level-01.md) · 로그 버킷 확보
  - [Defender Level 2](flaws2-cloud/defender/level-02.md) · jq 로 공격자 식별
  - [Defender Level 3](flaws2-cloud/defender/level-03.md) · 악의적 API 호출 분석
  - [Defender Level 4](flaws2-cloud/defender/level-04.md) · Athena 환경 구성
  - [Defender Level 5](flaws2-cloud/defender/level-05.md) · 타임라인 재구성

---

## 🚀 학습 로드맵 (권장 순서)

1. `docs/00-prerequisites.md` 로 환경 구성 확인
2. `docs/aws-security-primer.md` 로 개념 워밍업 (특히 **IAM 사용자/역할 차이**, **IMDSv1 vs v2** 는 꼭)
3. **flaws.cloud 1~6** 을 순서대로 — 각 레벨 힌트만 보고 10분 시도 → 막히면 풀이 열기
4. **flaws2.cloud Attacker 1~3** 으로 서버리스/컨테이너 감각 익히기
5. **flaws2.cloud Defender 1~5** 로 방어 시각 이해
6. 각 레벨 끝의 `방어 대책` 섹션을 **본인의 실제 AWS 계정**에 적용해 보기

---

## 📂 저장소 구조

```
.
├── README.md                 # 지금 읽는 파일
├── LICENSE
├── docs/
│   ├── 00-prerequisites.md
│   └── aws-security-primer.md
├── flaws-cloud/
│   ├── README.md
│   └── level-01.md ... level-06.md
├── flaws2-cloud/
│   ├── README.md
│   ├── attacker/level-0{1..3}.md
│   └── defender/level-0{1..5}.md
├── assets/                   # (선택) 다이어그램·스크린샷
├── feature-list.json         # 하네스용 진행 상태
└── tests/e2e/                # 각 문서의 구조·완성도 검증 스크립트
```

---

## 🤝 기여

오타·더 나은 예시·한국어 표현 수정은 PR 환영합니다. 각 레벨 문서의 섹션 구조(`## 🎯 목표`, `## 🛠 풀이` 등)는 테스트로 강제되므로 바꿀 때는 `tests/e2e/lib/common.sh` 도 함께 업데이트해 주세요.

## 📝 라이선스

[MIT](LICENSE). 원본 CTF 와 공식 힌트의 저작권은 [Scott Piper / SummitRoute](https://summitroute.com/) 에 있습니다. 본 저장소는 해당 CTF 의 **비영리 학습용 한국어 해설** 입니다.

## 🙏 참고 자료

- 공식: http://flaws.cloud/, http://flaws2.cloud/
- Scott Piper 블로그: https://summitroute.com
- 영문 walkthrough (교차 검증용):
  - `dominicbreuker.com/post/flaws_cloud_lvl1`
  - `cloudsecurity.club/p/solving-flaws-cloud`
  - `philkeeble.com/cloud/Flaws.Cloud-Walkthrough`
  - `muratbekgi.com/flaws2-cloud-walkthrough-all-flaws2-cloud-levels`
  - GitHub `kh4sh3i/Cloud-Flaws-CTF`
