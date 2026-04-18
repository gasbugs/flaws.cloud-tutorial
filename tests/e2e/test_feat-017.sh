#!/usr/bin/env bash
# feat-017: flaws2 Defender Level 4
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

F=flaws2-cloud/defender/level-04.md
require_file "$F"
for h in "목표" "공식 힌트" "사전 지식" "풀이" "방어 대책" "체크리스트"; do
  require_section "$F" "$h"
done
require_code_fence "$F" 3
require_grep "$F" 'CREATE EXTERNAL TABLE|EXTERNAL TABLE'
require_grep "$F" 'PARTITIONED BY|PARTITION'
require_grep "$F" 'JsonSerDe|json'
require_grep "$F" 'Athena|athena'
require_no_placeholder "$F"
echo "PASS: feat-017 (Defender L4)"
