#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

##USEAGE bash 02_get_hifi_from_config.sh ../refgenomes_pipeline.conf

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <config.conf>" >&2
  exit 1
fi

CONFIG_FILE="$1"
[[ -f "$CONFIG_FILE" ]] || { echo "Config not found: $CONFIG_FILE" >&2; exit 1; }

# Load config (bash-compatible KEY=VALUE)
set -a
# shellcheck disable=SC1090
source "$CONFIG_FILE"
set +a

# expand {user} placeholders in paths
USER_REAL="${USER:-$(whoami)}"
expand_user() { printf '%s' "${1//\{user\}/$USER_REAL}"; }

SAMPLESHEET="$(expand_user "${SAMPLESHEET}")"
RCLONE_FLAGS="${RCLONE_FLAGS:-}"

[[ -f "$SAMPLESHEET" ]] || { echo "Samplesheet not found: $SAMPLESHEET" >&2; exit 1; }

# Helper: trim CR/LF and leading/trailing whitespace
clean() { printf '%s' "$1" | tr -d '\r' | xargs; }


HIFI_BUCKET="${HIFI_BUCKET:?Missing HIFI_BUCKET in config}"
tmp_list="$(mktemp)"
trap 'rm -f "$tmp_list"' EXIT

declare -A HIFI_DIR_MAP
samples=()

# map sample -> hifi_dir (col1 -> col2)
while IFS=$'\t' read -r sample hifi_dir; do
  sample="$(clean "$sample")"
  hifi_dir="$(clean "$hifi_dir")"
  [[ -z "$sample" ]] && continue
  HIFI_DIR_MAP["$sample"]="$(expand_user "$hifi_dir")"
  samples+=("$sample")
done < <(awk -F, 'NR>1 { gsub(/\r/,"",$1); gsub(/\r/,"",$2); print $1 "\t" $2 }' "$SAMPLESHEET")

[[ ${#samples[@]} -gt 0 ]] || { echo "No samples found in $SAMPLESHEET" >&2; exit 1; }

include=()
for s in "${samples[@]}"; do
  include+=( --include "*${s}*hifi_reads*" )
done

rclone ls "$HIFI_BUCKET" ${RCLONE_FLAGS:+$RCLONE_FLAGS} "${include[@]}" > "$tmp_list"

while IFS= read -r line || [[ -n "$line" ]]; do
  path="$(printf '%s' "$line" | sed -E 's/^[[:space:]]*[0-9]+[[:space:]]+//; s/\r$//')"
  if ! printf '%s' "$path" | grep -qi 'hifi_reads'; then
    continue
  fi

  og="$(printf '%s' "$path" | grep -o -m1 -E 'OG[0-9]+' || true)"

  target=""
  if [[ -n "$og" && -n "${HIFI_DIR_MAP[$og]:-}" ]]; then
    target="${HIFI_DIR_MAP[$og]}"
  else
    for s in "${samples[@]}"; do
      if [[ "$path" == *"$s"* ]]; then
        target="${HIFI_DIR_MAP[$s]}"
        og="$s"
        break
      fi
    done
  fi

if [[ -z "$target" ]]; then
  echo "ERROR: No hic_dir found for remote path: $path" >&2
  exit 1
fi

  mkdir -p "$target"
  echo "Copying ${HIFI_BUCKET}/${path} -> ${target}/"
  rclone copy ${RCLONE_FLAGS:+$RCLONE_FLAGS} "${HIFI_BUCKET}/${path}" "${target}/"
done < "$tmp_list"

echo "Done."
