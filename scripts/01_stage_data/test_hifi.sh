#!/usr/bin/env bash
set -euo pipefail

OG_LIST="OG.txt"  # file containing OG IDs, one per line (e.g., OG0001)
S3_BUCKET="s3:oceanomics/OceanGenomes/pacbio-sra"
OUT="to_download-pacbio.txt"

# 1) Build a list of matching object paths (files only)
: > "$OUT"
while read -r og; do
  [[ -z "$og" ]] && continue
  rclone lsf "$S3_BUCKET" --files-only --include "*${og}*hifi_reads*" >> "$OUT"
done < "$OG_LIST"

# 2) Copy each file into its OG-specific directory
while read -r path; do
  [[ -z "$path" ]] && continue
  og=$(echo "$path" | grep -o 'OG[0-9]\+')
  [[ -z "$og" ]] && { echo "WARN: no OG in path: $path"; continue; }
  dest="/scratch/pawsey0964/tpeirce/ref-gen/${og}/hifi"
  rclone copy "$S3_BUCKET/$path" "$dest"
done < "$OUT"
