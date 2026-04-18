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
require_grep "$F" 'cognito-identity'
require_grep "$F" 'IdentityPoolId|identity-pool-id'
require_grep "$F" 'lambda.*get-function|get-function'
require_grep "$F" 'us-east-1'
require_no_placeholder "$F"
echo "PASS: feat-011 (Attacker L1)"
