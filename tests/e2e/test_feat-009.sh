#!/usr/bin/env bash
# feat-009: flaws.cloud Level 6 구조 검증
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

F=flaws-cloud/level-06.md
require_file "$F"
for h in "목표" "공식 힌트" "사전 지식" "정찰" "취약점 원리" "풀이" "방어 대책" "체크리스트"; do
  require_section "$F" "$h"
done
require_code_fence "$F" 4
require_grep "$F" 'SecurityAudit|MySecurityAudit'
require_grep "$F" 'list-attached-user-policies'
require_grep "$F" 'lambda get-policy'
require_grep "$F" 'apigateway'
require_grep "$F" 's33ppypa75'
require_grep "$F" 'theend-|theEnd-|the-end-'
require_no_placeholder "$F"
echo "PASS: feat-009 (Level 6)"
