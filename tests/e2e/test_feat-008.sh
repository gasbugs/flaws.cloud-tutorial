#!/usr/bin/env bash
# feat-008: flaws.cloud Level 5 구조 검증
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

F=flaws-cloud/level-05.md
require_file "$F"
for h in "목표" "공식 힌트" "사전 지식" "정찰" "취약점 원리" "풀이" "방어 대책" "체크리스트"; do
  require_section "$F" "$h"
done
require_code_fence "$F" 4
require_grep "$F" '169\.254\.169\.254'
require_grep "$F" 'proxy'
require_grep "$F" 'security-credentials'
require_grep "$F" 'AWS_SESSION_TOKEN'
require_grep "$F" 'http-tokens required'
require_no_placeholder "$F"
echo "PASS: feat-008 (Level 5)"
