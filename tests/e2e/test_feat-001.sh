#!/usr/bin/env bash
# feat-001: 저장소 스캐폴드 검증
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

require_file README.md
require_file LICENSE
require_file docs/00-prerequisites.md
require_dir flaws-cloud
require_dir flaws2-cloud/attacker
require_dir flaws2-cloud/defender
require_dir tests/e2e/lib
require_file tests/e2e/lib/common.sh

# README 핵심 섹션
require_section README.md "목차"
require_section README.md "학습 로드맵"
require_section README.md "라이선스"

# prerequisites 핵심 섹션
require_section docs/00-prerequisites.md "필수 도구"
require_section docs/00-prerequisites.md "AWS 계정 필요 여부"
require_section docs/00-prerequisites.md "윤리"

require_no_placeholder README.md
require_no_placeholder docs/00-prerequisites.md

echo "PASS: feat-001 (스캐폴드)"
