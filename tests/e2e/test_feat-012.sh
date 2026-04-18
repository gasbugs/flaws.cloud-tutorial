#!/usr/bin/env bash
# feat-012: flaws2 Attacker Level 2
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

F=flaws2-cloud/attacker/level-02.md
require_file "$F"
for h in "목표" "공식 힌트" "사전 지식" "정찰" "취약점 원리" "풀이" "방어 대책" "체크리스트"; do
  require_section "$F" "$h"
done
require_code_fence "$F" 4
require_grep "$F" 'ecr'
require_grep "$F" 'describe-images|batch-get-image'
require_grep "$F" 'htpasswd'
require_grep "$F" 'flaws2:secret_password'
require_grep "$F" 'BuildKit|멀티스테이지|Multi-stage|멀티-스테이지'
require_no_placeholder "$F"
echo "PASS: feat-012 (Attacker L2)"
