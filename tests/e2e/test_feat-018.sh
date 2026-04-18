#!/usr/bin/env bash
# feat-018: flaws2 Defender Level 5
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

F=flaws2-cloud/defender/level-05.md
require_file "$F"
for h in "목표" "공식 힌트" "쿼리" "방어 대책" "체크리스트"; do
  require_section "$F" "$h"
done
require_code_fence "$F" 3
require_grep "$F" 'SELECT'
require_grep "$F" 'GROUP BY|group by'
require_grep "$F" 'accessKeyId'
require_grep "$F" '타임라인|timeline'
require_no_placeholder "$F"
echo "PASS: feat-018 (Defender L5)"
