#!/usr/bin/env bash
# feat-013: flaws2 Attacker Level 3
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

F=flaws2-cloud/attacker/level-03.md
require_file "$F"
for h in "목표" "공식 힌트" "사전 지식" "정찰" "취약점 원리" "풀이" "방어 대책" "체크리스트"; do
  require_section "$F" "$h"
done
require_code_fence "$F" 4
require_grep "$F" '169\.254\.170\.2'
require_grep "$F" 'AWS_CONTAINER_CREDENTIALS_RELATIVE_URI'
require_grep "$F" 'Task Role|TaskRole|task role'
require_grep "$F" 'GuardDuty|SSRF'
require_no_placeholder "$F"
echo "PASS: feat-013 (Attacker L3)"
