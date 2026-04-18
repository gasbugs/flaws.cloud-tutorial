#!/usr/bin/env bash
# feat-014: flaws2 Defender Level 1
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

F=flaws2-cloud/defender/level-01.md
require_file "$F"
for h in "목표" "공식 힌트" "사전 지식" "풀이" "방어 대책" "체크리스트"; do
  require_section "$F" "$h"
done
require_code_fence "$F" 3
require_grep "$F" 'aws s3 sync'
require_grep "$F" 'CloudTrail'
require_grep "$F" 'Object Lock|ObjectLock'
require_grep "$F" 'flaws2-logs|AWSLogs'
require_no_placeholder "$F"
echo "PASS: feat-014 (Defender L1)"
