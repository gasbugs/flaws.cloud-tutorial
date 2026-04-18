#!/usr/bin/env bash
# feat-007: flaws.cloud Level 4 구조 검증
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

F=flaws-cloud/level-04.md
require_file "$F"
for h in "목표" "공식 힌트" "사전 지식" "정찰" "취약점 원리" "풀이" "방어 대책" "체크리스트"; do
  require_section "$F" "$h"
done
require_code_fence "$F" 4
require_grep "$F" 'describe-snapshots'
require_grep "$F" 'create-volume'
require_grep "$F" 'htpasswd'
require_grep "$F" 'ebs-snapshot-public-restorable-check'
require_grep "$F" '975426262029'
require_no_placeholder "$F"
echo "PASS: feat-007 (Level 4)"
