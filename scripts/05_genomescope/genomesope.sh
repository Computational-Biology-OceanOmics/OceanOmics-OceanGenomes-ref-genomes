#!/bin/bash --login
# genomesope.sh — Re-run GenomeScope2 with -l 50 for samples where the model
# returned 100% homozygosity (indicating the default lower k-mer limit failed).
#
# For each OG in the samplesheet:
#   1. Read the existing genomescope2 summary from the pipeline output
#   2. If max Homozygous == 100% (model failed), re-run with -l 50
#   3. If the new result is NOT 100%, replace the pipeline files with the new ones
#      (originals are preserved with a .pipeline_orig suffix)
#   4. If still 100%, log a warning and leave the original in place
#
# Usage (standalone):
#   bash genomesope.sh <samplesheet.csv> [OG1,OG2,...]
#
# Usage (via SLURM — submitted by post-assembly.py):
#   sbatch genomesope.sh <samplesheet.csv> [OG1,OG2,...]
#
#SBATCH --job-name=genomescope_rerun
#SBATCH --account=pawsey0964
#SBATCH --partition=work
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=01:00:00
#SBATCH --export=ALL
#SBATCH --output=%x-%j.out
#SBATCH --mail-type=FAIL
#SBATCH --mail-user=lauren.huet@uwa.edu.au

# ── Config ────────────────────────────────────────────────────────────────────

STAGING_BASE="/scratch/pawsey0964/$USER/ref-gen"
SING="/software/projects/pawsey0964/singularity"
GENOMESCOPE_SIF="${SING}/genomescope2:2.0.sif"

# ── Args ──────────────────────────────────────────────────────────────────────

SAMPLESHEET="${1:-}"
OG_FILTER="${2:-}"     # optional comma-separated list, e.g. OG1560,OG2132

if [[ -z "$SAMPLESHEET" || ! -f "$SAMPLESHEET" ]]; then
    echo "ERROR: samplesheet not found: $SAMPLESHEET"
    echo "Usage: $0 <samplesheet.csv> [OG1,OG2,...]"
    exit 1
fi

# ── Helpers ───────────────────────────────────────────────────────────────────

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

# Parse max Homozygous value from a genomescope summary file.
# Returns the max value (e.g. "100%" or "98.7796%"), or empty string if not found.
get_max_homozygosity() {
    local summary="$1"
    # Line looks like: "Homozygous (aa)               0%                100%"
    grep "Homozygous (aa)" "$summary" | awk '{print $NF}'
}

# ── Parse samplesheet ─────────────────────────────────────────────────────────

# Build arrays from the CSV (skip header)
declare -A OG_DATE
declare -A OG_VER

while IFS=',' read -r sample hifi_dir hic_dir version date rest; do
    [[ "$sample" == "sample" ]] && continue
    [[ -z "$sample" ]] && continue
    OG_DATE["$sample"]="$date"
    OG_VER["$sample"]="$version"
done < "$SAMPLESHEET"

# Apply OG filter if provided
if [[ -n "$OG_FILTER" ]]; then
    declare -A FDATE
    declare -A FVER
    IFS=',' read -ra FILTER_LIST <<< "$OG_FILTER"
    for og in "${FILTER_LIST[@]}"; do
        og="${og// /}"
        if [[ -n "${OG_DATE[$og]+x}" ]]; then
            FDATE["$og"]="${OG_DATE[$og]}"
            FVER["$og"]="${OG_VER[$og]}"
        fi
    done
    unset OG_DATE OG_VER
    declare -A OG_DATE
    declare -A OG_VER
    for og in "${!FDATE[@]}"; do
        OG_DATE["$og"]="${FDATE[$og]}"
        OG_VER["$og"]="${FVER[$og]}"
    done
fi

log "Checking ${#OG_DATE[@]} OG(s): $(echo "${!OG_DATE[@]}" | tr ' ' ',')"

# ── Process each OG ───────────────────────────────────────────────────────────

RERUN_COUNT=0
REPLACED_COUNT=0
STILL_100_COUNT=0
REPLACED_OGS=()

for og in $(echo "${!OG_DATE[@]}" | tr ' ' '\n' | sort); do
    date="${OG_DATE[$og]}"
    ver="${OG_VER[$og]}"
    gscope_dir="${STAGING_BASE}/${og}/02-kmer-profiling/genomescope2"
    summary="${gscope_dir}/${og}_genomescope_summary.txt"
    # Prefer exact path from samplesheet; fall back to glob when version mismatches
    hist="${STAGING_BASE}/${og}/02-kmer-profiling/meryl/${og}_${date}.${ver}.hist"
    if [[ ! -f "$hist" ]]; then
        hist=$(ls "${STAGING_BASE}/${og}/02-kmer-profiling/meryl/"*.hist 2>/dev/null | head -1)
    fi

    # ── Check if summary exists ───────────────────────────────────────────────
    if [[ ! -f "$summary" ]]; then
        log "SKIP $og — summary not found: $summary"
        continue
    fi

    max_hom=$(get_max_homozygosity "$summary")
    log "$og — max homozygosity: $max_hom"

    if [[ "$max_hom" != "100%" ]]; then
        log "$og — OK (model converged), no rerun needed"
        continue
    fi

    # ── 100% detected — rerun with -l 50 ─────────────────────────────────────
    log "$og — 100% homozygosity detected (model failed), re-running with -l 50"
    RERUN_COUNT=$((RERUN_COUNT + 1))

    if [[ ! -f "$hist" ]]; then
        log "ERROR $og — hist file not found: $hist"
        continue
    fi

    tmp_dir="${gscope_dir}/_rerun_l50"
    mkdir -p "$tmp_dir"

    # Do NOT pass --testing: that forces TESTING mode again, defeating the purpose
    singularity run "$GENOMESCOPE_SIF" genomescope2 \
        --input "$hist" \
        -l 50 \
        --output "$tmp_dir" \
        --name_prefix "${og}_genomescope" \
        -p 2

    new_summary="${tmp_dir}/${og}_genomescope_summary.txt"
    if [[ ! -f "$new_summary" ]]; then
        log "ERROR $og — rerun produced no summary, leaving original in place"
        rm -rf "$tmp_dir"
        continue
    fi

    new_max_hom=$(get_max_homozygosity "$new_summary")
    log "$og — rerun (-l 50) max homozygosity: $new_max_hom"

    if [[ "$new_max_hom" == "100%" ]]; then
        log "WARN $og — still 100% after rerun, keeping original pipeline result"
        STILL_100_COUNT=$((STILL_100_COUNT + 1))
        rm -rf "$tmp_dir"
        continue
    fi

    # ── New result is good — replace pipeline files ───────────────────────────
    log "$og — replacing pipeline genomescope files with -l 50 result"

    # Back up all original pipeline-generated files (except versions.yml)
    for f in "${gscope_dir}/${og}_genomescope"*; do
        [[ -f "$f" ]] && mv "$f" "${f}.pipeline_orig"
    done

    # Move new files into the genomescope2 directory
    for f in "${tmp_dir}/${og}_genomescope"*; do
        [[ -f "$f" ]] && mv "$f" "${gscope_dir}/"
    done

    rm -rf "$tmp_dir"

    REPLACED_COUNT=$((REPLACED_COUNT + 1))
    REPLACED_OGS+=("$og")
    log "$og — done. Original files saved as *.pipeline_orig"
done

# ── Summary ───────────────────────────────────────────────────────────────────

log "========================================"
log "GenomeScope rerun summary"
log "  OGs checked:   ${#OG_DATE[@]}"
log "  Reruns run:    $RERUN_COUNT"
log "  Files replaced: $REPLACED_COUNT"
log "  Still 100%:    $STILL_100_COUNT (original kept)"
if [[ ${#REPLACED_OGS[@]} -gt 0 ]]; then
    log "  Replaced OGs:  $(IFS=','; echo "${REPLACED_OGS[*]}")"
fi
log "========================================"

exit 0
