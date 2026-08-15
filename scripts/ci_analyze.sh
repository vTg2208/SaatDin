#!/usr/bin/env bash
# Flutter analyzer issue-count guardrail.

set -euo pipefail

BASELINE=0

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

ANALYZE_OUTPUT=$(flutter analyze 2>&1 || true)

echo "$ANALYZE_OUTPUT"
echo ""

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
fi

echo ""
echo "PASS: Analyzer issue count is within the allowed ceiling."
