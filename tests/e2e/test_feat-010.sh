#!/usr/bin/env bash
# feat-010: flaws2-cloud 색인 검증
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

F=flaws2-cloud/README.md
require_file "$F"
require_section "$F" "Attacker"
require_section "$F" "Defender"
require_section "$F" "학습 순서"
for n in 01 02 03; do
  grep -q "](attacker/level-${n}.md)" "$(dirname "$0")/../../$F" || { echo "FAIL: attacker level-${n}.md 링크 누락"; exit 1; }
done
for n in 01 02 03 04 05; do
  grep -q "](defender/level-${n}.md)" "$(dirname "$0")/../../$F" || { echo "FAIL: defender level-${n}.md 링크 누락"; exit 1; }
done
require_no_placeholder "$F"
echo "PASS: feat-010 (flaws2 색인)"
