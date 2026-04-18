#!/usr/bin/env bash
# feat-003: flaws-cloud/README.md 색인 검증
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

F=flaws-cloud/README.md
require_file "$F"
require_section "$F" "레벨 요약"
require_section "$F" "학습 순서"
# 6개 level-XX.md 링크 존재 (실제 파일은 이후 feature에서 생성되므로 링크만 확인)
for n in 01 02 03 04 05 06; do
  grep -q "](level-${n}.md)" "$(dirname "$0")/../../$F" || { echo "FAIL: level-${n}.md 링크 누락"; exit 1; }
done
require_no_placeholder "$F"
echo "PASS: feat-003 (flaws-cloud 색인)"
