#!/usr/bin/env bash
# feat-019: GitHub 레포 생성 및 push 검증
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

cd "${ROOT}"

# origin 이 올바른 URL 을 가리키는가
git remote get-url origin | grep -q 'github.com[:/]gasbugs/flaws.cloud-tutorial' \
  || { echo "FAIL: origin 미설정 또는 잘못된 URL"; exit 1; }

# 업스트림 브랜치 설정
git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' >/dev/null 2>&1 \
  || { echo "FAIL: upstream 추적 브랜치 미설정"; exit 1; }

# 로컬과 원격이 동기화되어 있음
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git ls-remote origin main | awk '{print $1}')
[ "$LOCAL" = "$REMOTE" ] || { echo "FAIL: 로컬 HEAD($LOCAL) != 원격 main($REMOTE)"; exit 1; }

# gh 로 레포 존재 확인
gh repo view gasbugs/flaws.cloud-tutorial --json name,visibility,url \
  --jq '"repo=\(.name) vis=\(.visibility) url=\(.url)"' \
  || { echo "FAIL: gh repo view 실패"; exit 1; }

echo "PASS: feat-019 (GitHub 레포 push 완료)"
