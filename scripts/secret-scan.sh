#!/usr/bin/env bash
#
# Pre-push credential scan for the gergram fork.
#
# The upstream tree ships credential-shaped values (Firebase key, API hash, App Center
# secret, update feed). Those were replaced with placeholders at import time, but the
# tree changes with every upstream merge — so the check runs before every push.
#
# Usage: scripts/secret-scan.sh [staged-only]
#   staged-only  scan only files staged for the next commit
#
# Exit codes: 0 clean, 1 findings, 2 scanner unavailable

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 2

SCAN_MODE="${1:-all}"

if command -v rg >/dev/null 2>&1; then
  HAVE_RG=1
else
  HAVE_RG=0
fi

PATTERNS=(
  'AIza[0-9A-Za-z_-]{35}'
  'AKIA[0-9A-Z]{16}'
  'ASIA[0-9A-Z]{16}'
  'gh[pousr]_[0-9A-Za-z]{36,}'
  'github_pat_[0-9A-Za-z_]{50,}'
  'xox[baprs]-[0-9A-Za-z-]{10,}'
  'sk-[0-9A-Za-z]{32,}'
  'glpat-[0-9A-Za-z_-]{20,}'
  '-----BEGIN [A-Z ]*PRIVATE KEY-----'
  'apiHash[[:space:]]*=[[:space:]]*"[0-9a-f]{32}"'
  'APPCENTER_SECRET[[:space:]]*=[[:space:]]*[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
)

ALLOW=(
  'REPLACE_WITH_OWN_API_HASH'
  'REPLACE_WITH_OWN_APPCENTER_SECRET'
  'REPLACE_WITH_YOUR_APPLE_TEAM_ID'
  'REPLACE_WITH_OWN_FIREBASE'
  'dsa_pub'
  'BEGIN PUBLIC KEY'
  'BEGIN CERTIFICATE'
)

EXCLUDES=(
  --glob '!.research/**'
  --glob '!.git/**'
  --glob '!*.pem'
  --glob '!*.p12'
  --glob '!*.cer'
  --glob '!*.mobileprovision'
)

scan_tree() {
  local pattern="$1"
  if [ "$HAVE_RG" -eq 1 ]; then
    rg --no-heading --line-number --color=never -e "$pattern" "${EXCLUDES[@]}" . 2>/dev/null
  else
    grep -rInE --exclude-dir=.research --exclude-dir=.git --exclude='*.pem' --exclude='*.p12' --exclude='*.cer' -e "$pattern" . 2>/dev/null
  fi
}

scan_staged() {
  local pattern="$1"
  local files
  files="$(git diff --cached --name-only --diff-filter=ACM)"
  [ -z "$files" ] && return 0
  printf '%s\n' "$files" | while IFS= read -r file; do
    [ -f "$file" ] || continue
    case "$file" in
      *.pem|*.p12|*.cer|*.mobileprovision) continue ;;
    esac
    if [ "$HAVE_RG" -eq 1 ]; then
      rg --no-heading --line-number --color=never -e "$pattern" -- "$file" 2>/dev/null
    else
      grep -nE -e "$pattern" -- "$file" 2>/dev/null
    fi
  done
}

FINDINGS=0
for pattern in "${PATTERNS[@]}"; do
  if [ "$SCAN_MODE" = "staged-only" ]; then
    HITS="$(scan_staged "$pattern")"
  else
    HITS="$(scan_tree "$pattern")"
  fi
  [ -z "$HITS" ] && continue
  while IFS= read -r hit; do
    [ -z "$hit" ] && continue
    allowed=0
    for token in "${ALLOW[@]}"; do
      case "$hit" in
        *"$token"*) allowed=1 ;;
      esac
    done
    [ "$allowed" -eq 1 ] && continue
    printf 'secret-scan: FINDING %s\n' "$hit"
    FINDINGS=$((FINDINGS + 1))
  done <<< "$HITS"
done

if [ "$FINDINGS" -gt 0 ]; then
  echo
  echo "secret-scan: $FINDINGS finding(s). Push blocked."
  echo "Replace the value with your own or a placeholder, or add an explicit entry"
  echo "to ALLOW in scripts/secret-scan.sh if the value is public by design."
  exit 1
fi

echo "secret-scan: clean ($SCAN_MODE)"
exit 0
