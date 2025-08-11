#!/usr/bin/env bash
set -euo pipefail

# Usage: ./audit_assemblies.sh -c /path/to/samplesheet.csv [-r pawsey0964:oceanomics-refassemblies]
REMOTE_DEFAULT="pawsey0964:oceanomics-refassemblies"
CSV=""
REMOTE="$REMOTE_DEFAULT"

while getopts ":c:r:" opt; do
  case $opt in
    c) CSV="$OPTARG" ;;
    r) REMOTE="$OPTARG" ;;
    *) echo "Usage: $0 -c samplesheet.csv [-r remote]"; exit 1 ;;
  esac
done

if [[ -z "${CSV}" ]]; then
  echo "Error: -c samplesheet.csv is required"
  exit 1
fi

if [[ ! -f "${CSV}" ]]; then
  echo "Error: samplesheet file not found: ${CSV}"
  exit 1
fi

timestamp() { date +'%Y-%m-%d %H:%M:%S'; }

# --- helpers ---------------------------------------------------------------

# Check if a *file* exists at remote:path (exact path).
exists_file() {
  local path="$1"
  # rclone lsjson returns JSON array if file/dir exists; use --files-only for files
  if rclone lsjson --files-only "${path}" >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

# Check if a *directory* exists and is non-empty at remote:path
exists_dir_nonempty() {
  local path="$1"
  # Non-empty if lsf prints anything
  if rclone lsf "${path}" >/dev/null 2>&1; then
    # If lsf succeeds but no entries, treat as empty
    if [[ -n "$(rclone lsf "${path}" 2>/dev/null)" ]]; then
      return 0
    fi
  fi
  return 1
}

# Emit one CSV line
emit() {
  local og="$1"; shift
  local asm="$1"; shift
  local check="$1"; shift
  local status="$1"; shift
  local detail="$1"
  echo "${og},${asm},${check},${status},${detail}"
}

# --- main ------------------------------------------------------------------

REPORT="audit_report_$(date +%Y%m%d_%H%M%S).csv"
echo "OG,asm_ver,check,status,detail" > "${REPORT}"

# Expect header: sample,hifi_dir,hic_dir,version,date,tolid,taxid,species
# Your sample lines match this order.
tail -n +2 "${CSV}" | while IFS=',' read -r sample hifi_dir hic_dir version date tolid taxid species; do
  # Guard against blank lines
  [[ -z "${sample:-}" ]] && continue

  OG="${sample}"
  asm_ver="${date}.${version}"    # e.g. v240821.hic1
  base="${REMOTE}/${OG}/${OG}_${asm_ver}"

  # 1) meryl tar file (copied to top-level meryl folder for the OG)
  meryl_tar="${REMOTE}/${OG}/meryl/${OG}_${asm_ver}.meryldb.tar.gz"
  if exists_file "${meryl_tar}"; then
    emit "${OG}" "${asm_ver}" "meryl_tar" "OK" "${meryl_tar}"
  else
    emit "${OG}" "${asm_ver}" "meryl_tar" "MISSING" "${meryl_tar}"
  fi

  # 2) assembly files
  for f in \
    "assembly/${OG}_${asm_ver}.0.hifiasm.hap1.fasta" \
    "assembly/${OG}_${asm_ver}.0.hifiasm.hap2.fasta" \
    "assembly/${OG}_${asm_ver}.hic.hap1.p_ctg.gfa" \
    "assembly/${OG}_${asm_ver}.hic.hap2.p_ctg.gfa" \
    "assembly/${OG}_${asm_ver}.1.yahs.hap1_scaffolds_final.fa" \
    "assembly/${OG}_${asm_ver}.1.yahs.hap2_scaffolds_final.fa" \
  ; do
    path="${base}/${f}"
    if exists_file "${path}"; then
      emit "${OG}" "${asm_ver}" "assembly:$(basename "${f}")" "OK" "${path}"
    else
      emit "${OG}" "${asm_ver}" "assembly:$(basename "${f}")" "MISSING" "${path}"
    fi
  done

  # 3) gfastats summaries (hap1/hap2)
  for f in \
    "gfastats/${OG}_${asm_ver}.0.hifiasm.hap1.assembly_summary.txt" \
    "gfastats/${OG}_${asm_ver}.0.hifiasm.hap2.assembly_summary.txt" \
  ; do
    path="${base}/${f}"
    if exists_file "${path}"; then
      emit "${OG}" "${asm_ver}" "gfastats:$(basename "${f}")" "OK" "${path}"
    else
      emit "${OG}" "${asm_ver}" "gfastats:$(basename "${f}")" "MISSING" "${path}"
    fi
  done

  # 4) merqury dir (non-empty)
  if exists_dir_nonempty "${base}/merqury"; then
    emit "${OG}" "${asm_ver}" "merqury_dir" "OK" "${base}/merqury"
  else
    emit "${OG}" "${asm_ver}" "merqury_dir" "MISSING" "${base}/merqury"
  fi

  # 5) busco dir (non-empty; assembly + decontamination both copied here)
  if exists_dir_nonempty "${base}/busco"; then
    emit "${OG}" "${asm_ver}" "busco_dir" "OK" "${base}/busco"
  else
    emit "${OG}" "${asm_ver}" "busco_dir" "MISSING" "${base}/busco"
  fi

  # 6) BAMs (omni-c + decontamination PT)
  for f in \
    "bam/${OG}_${asm_ver}.hap1.mapped.contigs.bam" \
    "bam/${OG}_${asm_ver}.hap1.mapped.contigs.bam.bai" \
    "bam/${OG}_${asm_ver}.hap2.mapped.contigs.bam" \
    "bam/${OG}_${asm_ver}.hap2.mapped.contigs.bam.bai" \
    "bam/${OG}_${asm_ver}.dual.mapped.PT.bam" \
    "bam/${OG}_${asm_ver}.dual.mapped.PT.bam.bai" \
    "bam/${OG}_${asm_ver}.dual.stats.txt" \
    "bam/${OG}_${asm_ver}.hap1.mapped.PT.bam" \
    "bam/${OG}_${asm_ver}.hap1.mapped.PT.bam.bai" \
    "bam/${OG}_${asm_ver}.hic1.hap1.stats.txt" \
    "bam/${OG}_${asm_ver}.hap2.mapped.PT.bam" \
    "bam/${OG}_${asm_ver}.hap2.mapped.PT.bam.bai" \
    "bam/${OG}_${asm_ver}.hic1.hap2.stats.txt" \
  ; do
    path="${base}/${f}"
    if exists_file "${path}"; then
      emit "${OG}" "${asm_ver}" "bam:$(basename "${f}")" "OK" "${path}"
    else
      emit "${OG}" "${asm_ver}" "bam:$(basename "${f}")" "MISSING" "${path}"
    fi
  done

  # 7) decontamination results
  for sub in "decontamination/NCBI" "decontamination/tiara" "gfastats"; do
    path="${base}/${sub}"
    if exists_dir_nonempty "${path}"; then
      emit "${OG}" "${asm_ver}" "${sub}_dir" "OK" "${path}"
    else
      emit "${OG}" "${asm_ver}" "${sub}_dir" "MISSING" "${path}"
    fi
  done

  # 8) final fastas (directory exists and has at least one fasta/fa)
  asm_dir="${base}/assembly"
  if exists_dir_nonempty "${asm_dir}"; then
    # Optional: ensure at least one final fasta is present
    if rclone lsf --include "*final*.fa*" "${asm_dir}" | grep -q . ; then
      emit "${OG}" "${asm_ver}" "final_fasta" "OK" "${asm_dir}"
    else
      emit "${OG}" "${asm_ver}" "final_fasta" "MISSING" "${asm_dir} (no *final*.fa*)"
    fi
  else
    emit "${OG}" "${asm_ver}" "assembly_dir" "MISSING" "${asm_dir}"
  fi

  # 9) bedgraph files
  for f in \
    "bedgraph/${OG}_${asm_ver}.dual.hap.gaps.bedgraph" \
    "bedgraph/${OG}_${asm_ver}.dual.hap.bedgraph" \
    "bedgraph/${OG}_${asm_ver}_sorted_telomeric_locations.bedgraph" \
  ; do
    path="${base}/${f}"
    if exists_file "${path}"; then
      emit "${OG}" "${asm_ver}" "bedgraph:$(basename "${f}")" "OK" "${path}"
    else
      emit "${OG}" "${asm_ver}" "bedgraph:$(basename "${f}")" "MISSING" "${path}"
    fi
  done

  # 10) pretext (3 PNG snapshots + 3 .pretext)
  # Note: the backup script has a possible double-dot typo on hap1 (.tiara..hap1.pretext).
  for f in \
    "pretext/${OG}_${asm_ver}.2.tiara.dual.pretext_snapshotFullMap.png" \
    "pretext/${OG}_${asm_ver}.2.tiara.hap1.pretext_snapshotFullMap.png" \
    "pretext/${OG}_${asm_ver}.2.tiara.hap2.pretext_snapshotFullMap.png" \
  ; do
    path="${base}/${f}"
    if exists_file "${path}"; then
      emit "${OG}" "${asm_ver}" "pretext_png:$(basename "${f}")" "OK" "${path}"
    else
      emit "${OG}" "${asm_ver}" "pretext_png:$(basename "${f}")" "MISSING" "${path}"
    fi
  done

  # .pretext files – try normal names; if hap1 missing, also try the double-dot variant
  for f in \
    "pretext/${OG}_${asm_ver}.2.tiara.dual-hi-res.pretext" \
    "pretext/${OG}_${asm_ver}.2.tiara.hap2.pretext" \
  ; do
    path="${base}/${f}"
    if exists_file "${path}"; then
      emit "${OG}" "${asm_ver}" "pretext:$(basename "${f}")" "OK" "${path}"
    else
      emit "${OG}" "${asm_ver}" "pretext:$(basename "${f}")" "MISSING" "${path}"
    fi
  done
  # hap1 with typo fallback
  hap1_expected="${base}/pretext/${OG}_${asm_ver}.2.tiara.hap1.pretext"
  hap1_typo="${base}/pretext/${OG}_${asm_ver}.2.tiara..hap1.pretext"
  if exists_file "${hap1_expected}"; then
    emit "${OG}" "${asm_ver}" "pretext:${OG}_${asm_ver}.2.tiara.hap1.pretext" "OK" "${hap1_expected}"
  elif exists_file "${hap1_typo}"; then
    emit "${OG}" "${asm_ver}" "pretext:${OG}_${asm_ver}.2.tiara.hap1.pretext" "OK_WITH_TYPO" "${hap1_typo}"
  else
    emit "${OG}" "${asm_ver}" "pretext:${OG}_${asm_ver}.2.tiara.hap1.pretext" "MISSING" "${hap1_expected}"
  fi

  # 11) chromsyn PDF
  chromsyn="${base}/chromsyn/${OG}.hapsyn.pdf"
  if exists_file "${chromsyn}"; then
    emit "${OG}" "${asm_ver}" "chromsyn_pdf" "OK" "${chromsyn}"
  else
    emit "${OG}" "${asm_ver}" "chromsyn_pdf" "MISSING" "${chromsyn}"
  fi

  # 12) multiqc dir (non-empty)
  if exists_dir_nonempty "${base}/multiqc"; then
    emit "${OG}" "${asm_ver}" "multiqc_dir" "OK" "${base}/multiqc"
  else
    emit "${OG}" "${asm_ver}" "multiqc_dir" "MISSING" "${base}/multiqc"
  fi

done >> "${REPORT}"

echo
echo "==== SUMMARY ===="
awk -F',' 'NR>1 && $4=="MISSING" {count[$1]++} END {
    for (og in count) {
        print og ": " count[og] " files missing"
    }
}' "${REPORT}" | sort


echo "[$(timestamp)] Audit complete."
echo "Report: ${REPORT}"
