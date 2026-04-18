#!/usr/bin/env bash
# feat-004: flaws.cloud Level 1 구조 검증
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

F=flaws-cloud/level-01.md
require_file "$F"
for h in "목표" "공식 힌트" "사전 지식" "정찰" "취약점 원리" "풀이" "방어 대책" "체크리스트"; do
  require_section "$F" "$h"
done
require_code_fence "$F" 3
require_grep "$F" 'aws s3 ls.*flaws.cloud'
require_grep "$F" '--no-sign-request'
require_grep "$F" 'us-west-2'
require_grep "$F" 'PublicAccessBlock|put-public-access-block'
require_no_placeholder "$F"
echo "PASS: feat-004 (Level 1)"
