#!/usr/bin/env bash
# feat-005: flaws.cloud Level 2 구조 검증
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

F=flaws-cloud/level-02.md
require_file "$F"
for h in "목표" "공식 힌트" "사전 지식" "정찰" "취약점 원리" "풀이" "방어 대책" "체크리스트"; do
  require_section "$F" "$h"
done
require_code_fence "$F" 3
require_grep "$F" 'AuthenticatedUsers'
require_grep "$F" 'level2-c8b217a33fcf1f839f6f1f73a00a9ae7'
require_grep "$F" '--profile'
require_grep "$F" 'BucketOwnerEnforced'
require_no_placeholder "$F"
echo "PASS: feat-005 (Level 2)"
