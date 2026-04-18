#!/usr/bin/env bash
# feat-016: flaws2 Defender Level 3
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

F=flaws2-cloud/defender/level-03.md
require_file "$F"
for h in "목표" "공식 힌트" "사전 지식" "풀이" "방어 대책" "체크리스트"; do
  require_section "$F" "$h"
done
require_code_fence "$F" 3
require_grep "$F" 'errorCode'
require_grep "$F" 'requestParameters'
require_grep "$F" 'AccessDenied'
require_grep "$F" 'Recon:IAMUser|정찰'
require_no_placeholder "$F"
echo "PASS: feat-016 (Defender L3)"
