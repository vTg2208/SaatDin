#!/usr/bin/env bash
# ci_analyze.sh — Analyzer warning guardrail (Issue #19)
#
# Usage:
#   bash scripts/ci_analyze.sh [--baseline N]
#
# Behavior:
#   - Runs `flutter analyze` and extracts the warning/error/info count.
#   - Fails (exit 1) if the count exceeds the allowed baseline.
#   - Default baseline is 0 (zero-warning policy).
#   - Pass --baseline <N> to allow a temporary higher ceiling while
#     the team works through accumulated warnings.
#
# CI integration (GitHub Actions):
#   - name: Dart / Flutter analyzer guardrail
#     run: bash scripts/ci_analyze.sh

set -euo pipefail

BASELINE=0

# Parse optional --baseline argument
while [[ $# -gt 0 ]]; do
  case "$1" in
    --baseline)
      BASELINE="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1"
      exit 1
      ;;
  esac
done

echo "=== SaatDin Analyzer Guardrail ==="
echo "Allowed issue ceiling: $BASELINE"
echo ""

# Capture analyzer output
ANALYZE_OUTPUT=$(flutter analyze 2>&1 || true)

echo "$ANALYZE_OUTPUT"
echo ""

# Extract the issue count from the last summary line, e.g.:
#   "10 issues found."  →  10
#   "No issues found!"  →  0
LAST_LINE=$(echo "$ANALYZE_OUTPUT" | grep -E "(issues? found|No issues found)" | tail -1 || true)

if [[ "$LAST_LINE" == *"No issues found"* ]]; then
  COUNT=0
elif [[ "$LAST_LINE" =~ ([0-9]+)\ issue ]]; then
  COUNT="${BASH_REMATCH[1]}"
else
  echo "ERROR: Could not parse issue count from analyzer output."
  echo "Raw last line: $LAST_LINE"
  exit 1
fi

echo "Issue count found : $COUNT"
echo "Allowed ceiling   : $BASELINE"

if [[ "$COUNT" -gt "$BASELINE" ]]; then
  echo ""
  echo "FAIL: Analyzer issue count ($COUNT) exceeds allowed baseline ($BASELINE)."
  echo "Please fix new warnings before merging this PR."
  exit 1
else
  echo ""
  echo "PASS: Analyzer issue count is within the allowed ceiling."
  exit 0
fi
