#!/usr/bin/env bash
# feat-011: flaws2 Attacker Level 1
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

F=flaws2-cloud/attacker/level-01.md
require_file "$F"
for h in "목표" "공식 힌트" "사전 지식" "정찰" "취약점 원리" "풀이" "방어 대책" "체크리스트"; do
  require_section "$F" "$h"
done
require_code_fence "$F" 4
require_grep "$F" 'code=a'
require_grep "$F" 'AWS_ACCESS_KEY_ID'
require_grep "$F" 'AWS_SESSION_TOKEN'
require_grep "$F" 'execute-api.us-east-1.amazonaws.com'
require_grep "$F" 'secret-ppxVFdwV4DDtZm8vbQRvhxL8mE6wxNco'
require_grep "$F" 'us-east-1'
require_no_placeholder "$F"
echo "PASS: feat-011 (Attacker L1)"
