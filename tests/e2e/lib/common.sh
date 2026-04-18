#!/usr/bin/env bash
# tests/e2e/lib/common.sh
# ------------------------------------------------------------
# 공용 검증 함수
#   - require_file <path>                          파일 존재
#   - require_dir <path>                           디렉터리 존재
#   - require_section <file> <heading-substring>   ## 섹션 존재 (부분문자열)
#   - require_code_fence <file> <min-count>        ```fence 블록 최소 개수
#   - require_no_placeholder <file>                TODO/FIXME/작성중 문구 없음
#   - require_link <file> <relative-target>        상대 링크가 실제 파일인지
#   - require_grep <file> <pattern>                파일 내 패턴 존재
# 각 실패 시 종료 코드 1 로 스크립트 종료.
# ------------------------------------------------------------
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

_fail() {
  echo "FAIL: $*" >&2
  exit 1
}

require_file() {
  local p="$1"
  [ -f "${ROOT}/${p}" ] || _fail "파일 없음: ${p}"
}

require_dir() {
  local p="$1"
  [ -d "${ROOT}/${p}" ] || _fail "디렉터리 없음: ${p}"
}

require_section() {
  local f="$1" h="$2"
  require_file "$f"
  grep -qE "^##+ .*${h}" "${ROOT}/${f}" || _fail "섹션 누락(${h}): ${f}"
}

require_code_fence() {
  local f="$1" min="${2:-1}"
  require_file "$f"
  local n
  n=$(grep -c '^```' "${ROOT}/${f}" || true)
  # 여닫는 쌍 → /2
  n=$(( n / 2 ))
  [ "$n" -ge "$min" ] || _fail "코드블록 부족(${n}/${min}): ${f}"
}

require_no_placeholder() {
  local f="$1"
  require_file "$f"
  if grep -nE 'TODO|FIXME|\(작성중\)|\(작성 중\)|XXX-PLACEHOLDER' "${ROOT}/${f}" >/dev/null; then
    _fail "플레이스홀더 잔존: ${f}"
  fi
}

require_link() {
  local f="$1" target="$2"
  require_file "$f"
  grep -q "](${target})" "${ROOT}/${f}" || _fail "링크 누락 [${target}]: ${f}"
  [ -e "${ROOT}/$(dirname "$f")/${target}" ] || [ -e "${ROOT}/${target}" ] \
    || _fail "링크 대상 파일 없음: ${target} (from ${f})"
}

require_grep() {
  local f="$1" pat="$2"
  require_file "$f"
  grep -qE -- "$pat" "${ROOT}/${f}" || _fail "패턴 없음(${pat}): ${f}"
}
