#!/usr/bin/env bash
# feat-006: flaws.cloud Level 3 구조 검증
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

F=flaws-cloud/level-03.md
require_file "$F"
for h in "목표" "공식 힌트" "사전 지식" "정찰" "취약점 원리" "풀이" "방어 대책" "체크리스트"; do
  require_section "$F" "$h"
done
require_code_fence "$F" 4
require_grep "$F" '\.git'
require_grep "$F" 'aws s3 sync'
require_grep "$F" 'git log'
require_grep "$F" 'AKIA'
require_grep "$F" 'gitleaks|git-secrets|detect-secrets'
require_no_placeholder "$F"
echo "PASS: feat-006 (Level 3)"
