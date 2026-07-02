#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
AUDITOR="${SCRIPT_DIR}/audit_backup.sh"
CSV_FILE="${REPO_DIR}/assets/samplesheet.csv"
REMOTE="pawsey0964:oceanomics-refassemblies"

# You can override with: ./audit_loop.sh /path/to/sheet.csv
if [[ $# -ge 1 ]]; then
  CSV_FILE="$1"
fi

if [[ ! -x "${AUDITOR}" ]]; then
  echo "Error: auditor not found or not executable at ${AUDITOR}"
  exit 1
fi

"${AUDITOR}" -c "${CSV_FILE}" -r "${REMOTE}"
