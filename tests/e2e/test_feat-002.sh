#!/usr/bin/env bash
# feat-002: AWS 보안 primer 구조 검증
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

F=docs/aws-security-primer.md
require_file "$F"
require_section "$F" "목차"
require_section "$F" "S3"
require_section "$F" "IAM"
require_section "$F" "IMDS"
require_section "$F" "ECS"
require_section "$F" "Lambda"
require_section "$F" "CloudTrail"
require_section "$F" "EBS"
require_section "$F" "Access Key"
require_code_fence "$F" 3
require_grep "$F" '169\.254\.169\.254'
require_grep "$F" '169\.254\.170\.2'
require_grep "$F" 'AKIA'
require_grep "$F" 'ASIA'
require_no_placeholder "$F"
echo "PASS: feat-002 (AWS primer)"
