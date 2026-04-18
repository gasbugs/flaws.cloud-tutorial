#!/usr/bin/env bash
# feat-015: flaws2 Defender Level 2
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

F=flaws2-cloud/defender/level-02.md
require_file "$F"
for h in "목표" "공식 힌트" "사전 지식" "풀이" "방어 대책" "체크리스트"; do
  require_section "$F" "$h"
done
require_code_fence "$F" 3
require_grep "$F" 'jq'
require_grep "$F" 'sourceIPAddress'
require_grep "$F" 'userIdentity'
require_grep "$F" 'GuardDuty'
require_no_placeholder "$F"
echo "PASS: feat-015 (Defender L2)"
