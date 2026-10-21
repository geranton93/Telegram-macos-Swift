#!/usr/bin/env bash
#
# Credential scan for the gergram fork.
#
# Guards three things:
#   1. tracked files must not contain credential-shaped values;
#   2. ignored local files (Local.xcconfig) must never be staged;
#   3. no commit in the history may contain credential-shaped values.
#
# The upstream tree ships credential-shaped values (Firebase key, API hash, App Center
# secret, update feed). Those were replaced with placeholders at import time, but the
# tree changes with every upstream merge — so the check runs before every commit and
# every push.
#
# Usage: scripts/secret-scan.sh [tree|staged|history|all]
#
# Exit codes: 0 clean, 1 findings, 2 scanner unavailable

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 2

MODE="${1:-all}"

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
  'bot[0-9]{6,}:[0-9A-Za-z_-]{30,}'
  '-----BEGIN [A-Z ]*PRIVATE KEY-----'
  'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}'
  'apiHash[[:space:]]*=[[:space:]]*"[0-9a-f]{32}"'
  'APPCENTER_SECRET[[:space:]]*=[[:space:]]*[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
  'API_HASH[[:space:]]*=[[:space:]]*[0-9a-f]{32}'
  'API_HASH[[:space:]]*=[[:space:]]*"[0-9a-f]{32}"'
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

FINDINGS=0

report() {
  printf 'secret-scan: FINDING %s\n' "$1"
  FINDINGS=$((FINDINGS + 1))
}

is_allowed() {
  local hit="$1" token
  for token in "${ALLOW[@]}"; do
    case "$hit" in
      *"$token"*) return 0 ;;
    esac
  done
  return 1
}

grep_files() {
  local pattern="$1"; shift
  local files="$1"
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

scan_tree() {
  local pattern="$1"
  if [ "$HAVE_RG" -eq 1 ]; then
    rg --no-heading --line-number --color=never -e "$pattern" "${EXCLUDES[@]}" . 2>/dev/null
  else
    grep -rInE --exclude-dir=.research --exclude-dir=.git --exclude='*.pem' --exclude='*.p12' --exclude='*.cer' -e "$pattern" . 2>/dev/null
  fi
}

scan_history() {
  local pattern="$1"
  git log -p --no-color master 2>/dev/null | grep -nE -e "$pattern" | sed 's/^/history:/'
}

check_staged_ignored() {
  local staged
  staged="$(git diff --cached --name-only --diff-filter=ACM)"
  [ -z "$staged" ] && return 0
  printf '%s\n' "$staged" | while IFS= read -r file; do
    [ -z "$file" ] && continue
    if git check-ignore -q --no-index "$file" 2>/dev/null; then
      echo "secret-scan: FINDING staged file is gitignored and holds local secrets: $file"
    fi
  done
}

case "$MODE" in
  tree)   SCOPE=tree ;;
  staged) SCOPE=staged ;;
  history) SCOPE=history ;;
  all)    SCOPE=all ;;
  *) echo "usage: $0 [tree|staged|history|all]"; exit 2 ;;
esac

if [ "$SCOPE" = "tree" ] || [ "$SCOPE" = "all" ]; then
  for pattern in "${PATTERNS[@]}"; do
    while IFS= read -r hit; do
      [ -z "$hit" ] && continue
      is_allowed "$hit" && continue
      report "$hit"
    done < <(scan_tree "$pattern")
  done
fi

if [ "$SCOPE" = "staged" ] || [ "$SCOPE" = "all" ]; then
  STAGED_FILES="$(git diff --cached --name-only --diff-filter=ACM)"
  for pattern in "${PATTERNS[@]}"; do
    while IFS= read -r hit; do
      [ -z "$hit" ] && continue
      is_allowed "$hit" && continue
      report "$hit"
    done < <(grep_files "$pattern" "$STAGED_FILES")
  done
  IGNORED_HITS="$(check_staged_ignored)"
  if [ -n "$IGNORED_HITS" ]; then
    printf '%s\n' "$IGNORED_HITS"
    FINDINGS=$((FINDINGS + $(printf '%s\n' "$IGNORED_HITS" | wc -l | tr -d ' ')))
  fi
fi

if [ "$SCOPE" = "history" ] || [ "$SCOPE" = "all" ]; then
  for pattern in "${PATTERNS[@]}"; do
    while IFS= read -r hit; do
      [ -z "$hit" ] && continue
      is_allowed "$hit" && continue
      report "$hit"
    done < <(scan_history "$pattern")
  done
fi

if [ "$FINDINGS" -gt 0 ]; then
  echo
  echo "secret-scan: $FINDINGS finding(s)."
  echo "Replace the value with your own or a placeholder, or add an explicit entry"
  echo "to ALLOW in scripts/secret-scan.sh if the value is public by design."
  exit 1
fi

echo "secret-scan: clean ($MODE)"
exit 0
