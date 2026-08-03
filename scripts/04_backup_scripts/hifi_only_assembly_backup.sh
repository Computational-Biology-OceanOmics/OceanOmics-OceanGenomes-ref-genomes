#!/bin/bash --login
#SBATCH --account=pawsey0964
#SBATCH --job-name=ocean-genomes
#SBATCH --partition=work
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --time=12:00:00
#SBATCH --export=NONE
#SBATCH --mail-type=BEGIN,END
#SBATCH --mail-user=lauren.huet@uwa.edu.au
#-----------------
#Loading the required modules


OG=$1
date=$2
asm_ver=$3
if [[ $OG == '' ]]
then
echo "Error: OG variable is empty or not set. Exiting."
exit
fi

# Ensure OG directory exists
if [[ ! -d $OG ]]; then
  echo "Error: Directory $OG does not exist. Exiting."
  exit 1
fi

# Every transfer is copied then immediately verified with `rclone check --checksum
# --one-way`. Failures are counted and reported in a summary at the end; the script
# exits non-zero if anything failed to copy or failed verification.
FAILURES=0
FAILED_ITEMS=()

copy_and_check() {
  local src="$1" dst="$2"

  echo "--- Backing up: $src -> $dst"

  if [[ ! -e "$src" ]]; then
    echo "    [FAIL] source does not exist"
    FAILURES=$((FAILURES + 1))
    FAILED_ITEMS+=("missing source: $src")
    return 1
  fi

  if ! rclone copy "$src" "$dst" --checksum --progress; then
    echo "    [FAIL] rclone copy failed"
    FAILURES=$((FAILURES + 1))
    FAILED_ITEMS+=("copy failed: $src")
    return 1
  fi

  if ! rclone check "$src" "$dst" --checksum --one-way; then
    echo "    [FAIL] rclone check mismatch"
    FAILURES=$((FAILURES + 1))
    FAILED_ITEMS+=("check failed: $src")
    return 1
  fi

  echo "    [OK] verified"
  return 0
}

# Tar kmer directories
rm -f success
tar -czvf ${OG}/02-kmer-profiling/meryl/${OG}_${date}.${asm_ver}.meryl.tar.gz -C ${OG}/02-kmer-profiling/meryl ${OG}_${date}.${asm_ver}.meryl && touch success

wait

# Remove only if tar was successful and the file exists
if [[ -f success ]]; then
  target_dir="${OG}/02-kmer-profiling/meryl/${OG}_${date}.${asm_ver}.meryl"
  if [[ -d $target_dir ]]; then
    rm -rf "$target_dir"
    echo "Removed directory: $target_dir"
  else
    echo "Error: Target directory $target_dir does not exist. Skipping removal."
  fi
fi

### Back up hifiadaptfilt reads to fastq

copy_and_check "${OG}/01-data-processing/hifiadaptfilt/${OG}_${date}.${asm_ver}/" "pawsey0964:oceanomics-filtered-reads/${OG}/hifi"


##back up kmer profilling (genomescope and meryl)
copy_and_check "${OG}/02-kmer-profiling/genomescope2/" "pawsey0964:oceanomics-refassemblies/${OG}/genomescope"
copy_and_check "${OG}/02-kmer-profiling/meryl/${OG}_${date}.${asm_ver}.meryl.tar.gz" "pawsey0964:oceanomics-refassemblies/${OG}/meryl"

#Back up hifiasm assemblies and gfa stats
# 1.Assemblies
copy_and_check "${OG}/03-assembly/gfastats-hifi/${OG}_${date}.${asm_ver}.0.hifiasm.a_ctg.fasta" "pawsey0964:oceanomics-refassemblies/${OG}/${OG}_${date}.${asm_ver}/assembly"
copy_and_check "${OG}/03-assembly/gfastats-hifi/${OG}_${date}.${asm_ver}.0.hifiasm.p_ctg.fasta" "pawsey0964:oceanomics-refassemblies/${OG}/${OG}_${date}.${asm_ver}/assembly"
copy_and_check "${OG}/03-assembly/hifi/${OG}_${date}.${asm_ver}.0.hifiasm.p_ctg.gfa" "pawsey0964:oceanomics-refassemblies/${OG}/${OG}_${date}.${asm_ver}/assembly"
copy_and_check "${OG}/03-assembly/hifi/${OG}_${date}.${asm_ver}.0.hifiasm.a_ctg.gfa" "pawsey0964:oceanomics-refassemblies/${OG}/${OG}_${date}.${asm_ver}/assembly"

#gfastats
copy_and_check "${OG}/03-assembly/gfastats-hifi/${OG}_${date}.${asm_ver}.0.hifiasm.a_ctg.assembly_summary.txt" "pawsey0964:oceanomics-refassemblies/${OG}/${OG}_${date}.${asm_ver}/gfastats"
copy_and_check "${OG}/03-assembly/gfastats-hifi/${OG}_${date}.${asm_ver}.0.hifiasm.p_ctg.assembly_summary.txt" "pawsey0964:oceanomics-refassemblies/${OG}/${OG}_${date}.${asm_ver}/gfastats"

# Back up MultiQC report
if [[ -d ${OG}/multiqc ]]; then
    copy_and_check "${OG}/multiqc/" "pawsey0964:oceanomics-refassemblies/${OG}/multiqc"
    echo "MultiQC backed up for ${OG}"
else
    echo "WARNING: no multiqc directory found for ${OG} — skipping"
fi

# ────────────────────────────────────────────────────────────────────────────
# Summary
# ────────────────────────────────────────────────────────────────────────────
echo ""
echo "=== Backup summary: ${OG}_${date}.${asm_ver} ==="
if [[ $FAILURES -eq 0 ]]; then
  echo "All transfers copied and verified with rclone check."
  exit 0
else
  echo "${FAILURES} transfer(s) failed:"
  for item in "${FAILED_ITEMS[@]}"; do
    echo "  - $item"
  done
  exit 1
fi

