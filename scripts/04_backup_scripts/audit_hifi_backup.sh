#!/usr/bin/env bash
# Audit hifi-only assembly files — checks either local scratch (pre-backup) or Acacia (post-backup).
#
# Usage:
#   audit_hifi_backup.sh -c samplesheet.csv -m local   # before backup: check scratch
#   audit_hifi_backup.sh -c samplesheet.csv -m remote  # after backup: check Acacia
#
# Samplesheet columns: sample,hifi_dir,hic_dir,version,date,tolid,taxid,species,...

set -euo pipefail

STAGING_BASE="/scratch/pawsey0964/lhuet/ref-gen"
REMOTE_READS="pawsey0964:oceanomics-filtered-reads"
REMOTE_ASM="pawsey0964:oceanomics-refassemblies"
CSV=""
MODE=""

while getopts ":c:m:" opt; do
  case $opt in
    c) CSV="$OPTARG" ;;
    m) MODE="$OPTARG" ;;
    *) echo "Usage: $0 -c samplesheet.csv -m local|remote"; exit 1 ;;
  esac
done

if [[ -z "${CSV}" || -z "${MODE}" ]]; then
  echo "Usage: $0 -c samplesheet.csv -m local|remote"
  exit 1
fi
if [[ ! -f "${CSV}" ]]; then
  echo "Error: samplesheet not found: ${CSV}"
  exit 1
fi
if [[ "${MODE}" != "local" && "${MODE}" != "remote" ]]; then
  echo "Error: -m must be 'local' or 'remote'"
  exit 1
fi

timestamp() { date +'%Y-%m-%d %H:%M:%S'; }

local_dir_ok()  { [[ -d "$1" && -n "$(ls -A "$1" 2>/dev/null)" ]] && echo OK || echo MISSING; }
local_file_ok() { [[ -f "$1" ]] && echo OK || echo MISSING; }
remote_dir_ok() {
  if rclone lsf "$1" >/dev/null 2>&1 && [[ -n "$(rclone lsf "$1" 2>/dev/null)" ]]; then
    echo OK
  else
    echo MISSING
  fi
}
remote_file_ok() {
  if rclone lsjson --files-only "$1" >/dev/null 2>&1 && \
     [[ -n "$(rclone lsjson --files-only "$1" 2>/dev/null)" ]]; then
    echo OK
  else
    echo MISSING
  fi
}

REPORT="audit_hifi_${MODE}_$(date +%Y%m%d_%H%M%S).csv"
echo "OG,asm_ver,check,status,detail" > "${REPORT}"

emit() { echo "$1,$2,$3,$4,$5" >> "${REPORT}"; }

echo "[$(timestamp)] Hifi-only ${MODE} audit: ${CSV}"

tail -n +2 "${CSV}" | while IFS=',' read -r sample hifi_dir hic_dir version date tolid taxid species rest; do
  [[ -z "${sample:-}" ]] && continue

  OG="${sample}"
  asm="${date}.${version}"          # e.g. v260227.hic1
  base_local="${STAGING_BASE}/${OG}"
  base_remote="${REMOTE_ASM}/${OG}/${OG}_${asm}"

  if [[ "${MODE}" == "local" ]]; then
    # ── Local checks ──────────────────────────────────────────────────────────

    # hifiadaptfilt output dir
    hadir="${base_local}/01-data-processing/hifiadaptfilt/${OG}_${asm}"
    s=$(local_dir_ok "${hadir}")
    emit "${OG}" "${asm}" "hifiadaptfilt_dir" "${s}" "${hadir}"

    # genomescope dir
    gsdir="${base_local}/02-kmer-profiling/genomescope2"
    s=$(local_dir_ok "${gsdir}")
    emit "${OG}" "${asm}" "genomescope_dir" "${s}" "${gsdir}"

    # meryl dir (pre-tar)
    meryldir="${base_local}/02-kmer-profiling/meryl/${OG}_${asm}.meryl"
    s=$(local_dir_ok "${meryldir}")
    emit "${OG}" "${asm}" "meryl_dir" "${s}" "${meryldir}"

    # assembly files
    gfa_dir="${base_local}/03-assembly/gfastats-hifi"
    hifi_dir_local="${base_local}/03-assembly/hifi"
    for suffix in \
        "p_ctg.fasta" "a_ctg.fasta" \
        "p_ctg.assembly_summary.txt" "a_ctg.assembly_summary.txt"; do
      f="${gfa_dir}/${OG}_${asm}.0.hifiasm.${suffix}"
      s=$(local_file_ok "${f}")
      emit "${OG}" "${asm}" "local:$(basename "${f}")" "${s}" "${f}"
    done
    for suffix in "p_ctg.gfa" "a_ctg.gfa"; do
      f="${hifi_dir_local}/${OG}_${asm}.0.hifiasm.${suffix}"
      s=$(local_file_ok "${f}")
      emit "${OG}" "${asm}" "local:$(basename "${f}")" "${s}" "${f}"
    done

  else
    # ── Remote checks ─────────────────────────────────────────────────────────

    # filtered reads bucket
    reads_dir="${REMOTE_READS}/${OG}/hifi"
    s=$(remote_dir_ok "${reads_dir}")
    emit "${OG}" "${asm}" "filtered_reads" "${s}" "${reads_dir}"

    # genomescope dir
    gs_remote="${REMOTE_ASM}/${OG}/genomescope"
    s=$(remote_dir_ok "${gs_remote}")
    emit "${OG}" "${asm}" "genomescope" "${s}" "${gs_remote}"

    # meryl tar
    meryl_tar="${REMOTE_ASM}/${OG}/meryl/${OG}_${asm}.meryl.tar.gz"
    s=$(remote_file_ok "${meryl_tar}")
    emit "${OG}" "${asm}" "meryl_tar" "${s}" "${meryl_tar}"

    # assembly files
    for suffix in \
        "p_ctg.fasta" "a_ctg.fasta" \
        "p_ctg.gfa" "a_ctg.gfa"; do
      f="${base_remote}/assembly/${OG}_${asm}.0.hifiasm.${suffix}"
      s=$(remote_file_ok "${f}")
      emit "${OG}" "${asm}" "remote:$(basename "${f}")" "${s}" "${f}"
    done

    # gfastats
    for suffix in "p_ctg.assembly_summary.txt" "a_ctg.assembly_summary.txt"; do
      f="${base_remote}/gfastats/${OG}_${asm}.0.hifiasm.${suffix}"
      s=$(remote_file_ok "${f}")
      emit "${OG}" "${asm}" "remote:$(basename "${f}")" "${s}" "${f}"
    done
  fi

done

echo ""
echo "==== MISSING ===="
awk -F',' 'NR>1 && $4=="MISSING" {print $1 " | " $3 " | " $5}' "${REPORT}"
echo ""
n_missing=$(awk -F',' 'NR>1 && $4=="MISSING"' "${REPORT}" | wc -l)
n_ok=$(awk -F',' 'NR>1 && $4=="OK"' "${REPORT}" | wc -l)
echo "[$(timestamp)] Done. OK=${n_ok}  MISSING=${n_missing}"
echo "Report: ${REPORT}"
