#!/bin/bash --login
#SBATCH --account=pawsey0812
#SBATCH --job-name=ocean-genomes-backup
#SBATCH --partition=work
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --time=24:00:00
#SBATCH --export=NONE
#SBATCH --mail-type=BEGIN,END
#SBATCH --mail-user=lauren.huet@uwa.edu.au
#-----------------
#
# Usage:
#   sbatch full_assembly_backup.sh <OG> <date> <version> [mode]
#
# Arguments:
#   OG       Sample ID, e.g. OG39
#   date     Assembly date component, e.g. v250331
#   version  Assembly version component, e.g. hic2
#   mode     Assembly mode (default: hifi_hic)
#            hifi_hic      - Standard HiFi + Hi-C dual-haplotype assembly
#            single_hap    - Precomputed single-haplotype assembly
#            dual_hap      - Precomputed dual-haplotype assembly (hap1 + hap2 provided)
#
# Examples:
#   sbatch full_assembly_backup.sh OG680 v241004 hic2 hifi_hic
#   sbatch full_assembly_backup.sh OG39  v250331 hic2 single_hap
#   sbatch full_assembly_backup.sh OG750 v250401 hic2 dual_hap

OG=$1
date=$2
version=$3
mode=${4:-hifi_hic}
asm_ver=${date}.${version}

# ── Validation ────────────────────────────────────────────────────────────────

if [[ -z "$OG" ]]; then
    echo "Error: OG variable is empty or not set. Exiting."
    exit 1
fi

if [[ ! -d "$OG" ]]; then
    echo "Error: Directory $OG does not exist. Exiting."
    exit 1
fi

if [[ "$mode" != "hifi_hic" && "$mode" != "single_hap" && "$mode" != "dual_hap" ]]; then
    echo "Error: Unknown mode '$mode'. Must be hifi_hic, single_hap, or dual_hap."
    exit 1
fi

echo "=== OceanGenomes backup ==="
echo "Sample : $OG"
echo "Version: $asm_ver"
echo "Mode   : $mode"
echo "==========================="

# ── Helper ────────────────────────────────────────────────────────────────────

rclone_copy() {
    local src="$1"
    local dst="$2"
    if [[ -e "$src" ]]; then
        rclone copy "$src" "pawsey0964:oceanomics-refassemblies/$dst" --checksum --progress
    else
        echo "SKIP (not found): $src"
    fi
}

# ── Shared: tar and back up meryl k-mer database ──────────────────────────────

rm -f success
tar -czvf "${OG}/02-kmer-profiling/meryl/${OG}_${asm_ver}.meryl.tar.gz" \
    -C "${OG}/02-kmer-profiling/meryl" "${OG}_${asm_ver}.meryl" && touch success

wait

if [[ -f success ]]; then
    target_dir="${OG}/02-kmer-profiling/meryl/${OG}_${asm_ver}.meryl"
    if [[ -d "$target_dir" ]]; then
        rm -rf "$target_dir"
        echo "Removed directory: $target_dir"
    else
        echo "Error: Target directory $target_dir does not exist. Skipping removal."
    fi
fi

# ── Shared: k-mer profiling ───────────────────────────────────────────────────

rclone_copy "${OG}/02-kmer-profiling/genomescope2/" \
    "${OG}/genomescope"
rclone_copy "${OG}/02-kmer-profiling/meryl/${OG}_${asm_ver}.meryl.tar.gz" \
    "${OG}/meryl"

# ── Shared: HiFi filtered reads ───────────────────────────────────────────────

rclone_copy "${OG}/01-data-processing/hifiadaptfilt/${OG}_${asm_ver}/" \
    "pawsey0964:oceanomics-filtered-reads/${OG}/hifi"

# ═════════════════════════════════════════════════════════════════════════════
# MODE: hifi_hic  — Standard HiFi + Hi-C dual-haplotype assembly
# ═════════════════════════════════════════════════════════════════════════════
if [[ "$mode" == "hifi_hic" ]]; then

    # Assembly FASTAs (output of GFASTATS_HAP1/HAP2 from Hifiasm contigs)
    rclone_copy "${OG}/03-assembly/gfastats/${OG}_${asm_ver}.1.hifiasm.hap1.fasta" \
        "${OG}/${OG}_${asm_ver}/assembly"
    rclone_copy "${OG}/03-assembly/gfastats/${OG}_${asm_ver}.1.hifiasm.hap2.fasta" \
        "${OG}/${OG}_${asm_ver}/assembly"

    # Raw Hifiasm GFA files
    rclone_copy "${OG}/03-assembly/hifiasm/${OG}_${asm_ver}.hic.hap1.p_ctg.gfa" \
        "${OG}/${OG}_${asm_ver}/assembly"
    rclone_copy "${OG}/03-assembly/hifiasm/${OG}_${asm_ver}.hic.hap2.p_ctg.gfa" \
        "${OG}/${OG}_${asm_ver}/assembly"

    # GFAstats assembly summaries
    rclone_copy "${OG}/03-assembly/gfastats/${OG}_${asm_ver}.1.hifiasm.hap1.assembly_summary.txt" \
        "${OG}/${OG}_${asm_ver}/gfastats"
    rclone_copy "${OG}/03-assembly/gfastats/${OG}_${asm_ver}.1.hifiasm.hap2.assembly_summary.txt" \
        "${OG}/${OG}_${asm_ver}/gfastats"

    # Merqury and BUSCO (contig-level)
    rclone_copy "${OG}/03-assembly/merqury" \
        "${OG}/${OG}_${asm_ver}/merqury"
    rclone_copy "${OG}/03-assembly/busco" \
        "${OG}/${OG}_${asm_ver}/busco"

    # OMNIC pre-scaffolding BAMs
    rclone_copy "${OG}/04-scaffolding/omnic/${OG}_${asm_ver}.hap1.mapped.contigs.bam" \
        "${OG}/${OG}_${asm_ver}/bam"
    rclone_copy "${OG}/04-scaffolding/omnic/${OG}_${asm_ver}.hap1.mapped.contigs.bam.bai" \
        "${OG}/${OG}_${asm_ver}/bam"
    rclone_copy "${OG}/04-scaffolding/omnic/${OG}_${asm_ver}.hap2.mapped.contigs.bam" \
        "${OG}/${OG}_${asm_ver}/bam"
    rclone_copy "${OG}/04-scaffolding/omnic/${OG}_${asm_ver}.hap2.mapped.contigs.bam.bai" \
        "${OG}/${OG}_${asm_ver}/bam"

    # YAHS scaffolds
    rclone_copy "${OG}/04-scaffolding/yahs/${OG}_${asm_ver}.2.yahs.hap1_scaffolds_final.fa" \
        "${OG}/${OG}_${asm_ver}/assembly"
    rclone_copy "${OG}/04-scaffolding/yahs/${OG}_${asm_ver}.2.yahs.hap2_scaffolds_final.fa" \
        "${OG}/${OG}_${asm_ver}/assembly"

    # OMNIC post-scaffolding BAMs (dual + hap1 + hap2)
    rclone_copy "${OG}/05-decontamination/omnic/${OG}_${asm_ver}.dual.mapped.PT.bam" \
        "${OG}/${OG}_${asm_ver}/bam"
    rclone_copy "${OG}/05-decontamination/omnic/${OG}_${asm_ver}.dual.mapped.PT.bam.bai" \
        "${OG}/${OG}_${asm_ver}/bam"
    rclone_copy "${OG}/05-decontamination/omnic/${OG}_${asm_ver}.dual.stats.txt" \
        "${OG}/${OG}_${asm_ver}/bam"
    rclone_copy "${OG}/05-decontamination/omnic/${OG}_${asm_ver}.hap1.mapped.PT.bam" \
        "${OG}/${OG}_${asm_ver}/bam"
    rclone_copy "${OG}/05-decontamination/omnic/${OG}_${asm_ver}.hap1.mapped.PT.bam.bai" \
        "${OG}/${OG}_${asm_ver}/bam"
    rclone_copy "${OG}/05-decontamination/omnic/${OG}_${asm_ver}.hic1.hap1.stats.txt" \
        "${OG}/${OG}_${asm_ver}/bam"
    rclone_copy "${OG}/05-decontamination/omnic/${OG}_${asm_ver}.hap2.mapped.PT.bam" \
        "${OG}/${OG}_${asm_ver}/bam"
    rclone_copy "${OG}/05-decontamination/omnic/${OG}_${asm_ver}.hap2.mapped.PT.bam.bai" \
        "${OG}/${OG}_${asm_ver}/bam"
    rclone_copy "${OG}/05-decontamination/omnic/${OG}_${asm_ver}.hic1.hap2.stats.txt" \
        "${OG}/${OG}_${asm_ver}/bam"

    # Decontamination QC
    rclone_copy "${OG}/05-decontamination/busco" \
        "${OG}/${OG}_${asm_ver}/busco"
    rclone_copy "${OG}/05-decontamination/gfastats" \
        "${OG}/${OG}_${asm_ver}/gfastats"
    rclone_copy "${OG}/05-decontamination/NCBI/out" \
        "${OG}/${OG}_${asm_ver}/decontamination/NCBI"
    rclone_copy "${OG}/05-decontamination/tiara" \
        "${OG}/${OG}_${asm_ver}/decontamination/tiara"
    rclone_copy "${OG}/05-decontamination/final-fastas/" \
        "${OG}/${OG}_${asm_ver}/assembly"

    # Coverage, telomere, pretext
    rclone_copy "${OG}/06-coverage-tracks/${OG}_${asm_ver}.dual.hap.gaps.bedgraph" \
        "${OG}/${OG}_${asm_ver}/bedgraph"
    rclone_copy "${OG}/06-coverage-tracks/${OG}_${asm_ver}.dual.hap.bedgraph" \
        "${OG}/${OG}_${asm_ver}/bedgraph"
    rclone_copy "${OG}/07-telomers" \
        "${OG}/${OG}_${asm_ver}/bedgraph"

    rclone_copy "${OG}/08-pretext/${OG}_${asm_ver}.2.tiara.dual.pretext_snapshotFullMap.png" \
        "${OG}/${OG}_${asm_ver}/pretext"
    rclone_copy "${OG}/08-pretext/${OG}_${asm_ver}.2.tiara.hap1.pretext_snapshotFullMap.png" \
        "${OG}/${OG}_${asm_ver}/pretext"
    rclone_copy "${OG}/08-pretext/${OG}_${asm_ver}.2.tiara.hap2.pretext_snapshotFullMap.png" \
        "${OG}/${OG}_${asm_ver}/pretext"
    rclone_copy "${OG}/08-pretext/${OG}_${asm_ver}.2.tiara.dual-hi-res.pretext" \
        "${OG}/${OG}_${asm_ver}/pretext"
    rclone_copy "${OG}/08-pretext/${OG}_${asm_ver}.2.tiara.hap1.pretext" \
        "${OG}/${OG}_${asm_ver}/pretext"
    rclone_copy "${OG}/08-pretext/${OG}_${asm_ver}.2.tiara.hap2.pretext" \
        "${OG}/${OG}_${asm_ver}/pretext"
    rclone_copy "${OG}/08-pretext/${OG}_${asm_ver}.2.tiara.dual.pretext" \
        "${OG}/${OG}_${asm_ver}/pretext"

    rclone_copy "${OG}/09-chromsyn/${OG}.hapsyn.pdf" \
        "${OG}/${OG}_${asm_ver}/chromsyn"

    rclone copy "${OG}/multiqc" \
        "pawsey0964:oceanomics-refassemblies/${OG}/${OG}_${asm_ver}/multiqc"

fi

# ═════════════════════════════════════════════════════════════════════════════
# MODE: dual_hap  — Precomputed hap1 + hap2 dual-haplotype assembly
#   Same pipeline as hifi_hic after GFASTATS, but no raw Hifiasm GFAs.
#   Assembly FASTAs come from 03-assembly/precomputed-dual/.
# ═════════════════════════════════════════════════════════════════════════════
if [[ "$mode" == "dual_hap" ]]; then

    # Prepared assembly FASTAs (from PREPARE_DUAL_ASSEMBLY)
    rclone_copy "${OG}/03-assembly/precomputed-dual/" \
        "${OG}/${OG}_${asm_ver}/assembly"

    # GFAstats assembly summaries (same dir as hifi_hic)
    rclone_copy "${OG}/03-assembly/gfastats/${OG}_${asm_ver}.1.hifiasm.hap1.assembly_summary.txt" \
        "${OG}/${OG}_${asm_ver}/gfastats"
    rclone_copy "${OG}/03-assembly/gfastats/${OG}_${asm_ver}.1.hifiasm.hap2.assembly_summary.txt" \
        "${OG}/${OG}_${asm_ver}/gfastats"

    # Merqury and BUSCO (contig-level)
    rclone_copy "${OG}/03-assembly/merqury" \
        "${OG}/${OG}_${asm_ver}/merqury"
    rclone_copy "${OG}/03-assembly/busco" \
        "${OG}/${OG}_${asm_ver}/busco"

    # OMNIC pre-scaffolding BAMs
    rclone_copy "${OG}/04-scaffolding/omnic/${OG}_${asm_ver}.hap1.mapped.contigs.bam" \
        "${OG}/${OG}_${asm_ver}/bam"
    rclone_copy "${OG}/04-scaffolding/omnic/${OG}_${asm_ver}.hap1.mapped.contigs.bam.bai" \
        "${OG}/${OG}_${asm_ver}/bam"
    rclone_copy "${OG}/04-scaffolding/omnic/${OG}_${asm_ver}.hap2.mapped.contigs.bam" \
        "${OG}/${OG}_${asm_ver}/bam"
    rclone_copy "${OG}/04-scaffolding/omnic/${OG}_${asm_ver}.hap2.mapped.contigs.bam.bai" \
        "${OG}/${OG}_${asm_ver}/bam"

    # YAHS scaffolds
    rclone_copy "${OG}/04-scaffolding/yahs/${OG}_${asm_ver}.2.yahs.hap1_scaffolds_final.fa" \
        "${OG}/${OG}_${asm_ver}/assembly"
    rclone_copy "${OG}/04-scaffolding/yahs/${OG}_${asm_ver}.2.yahs.hap2_scaffolds_final.fa" \
        "${OG}/${OG}_${asm_ver}/assembly"

    # OMNIC post-scaffolding BAMs (dual + hap1 + hap2)
    rclone_copy "${OG}/05-decontamination/omnic/${OG}_${asm_ver}.dual.mapped.PT.bam" \
        "${OG}/${OG}_${asm_ver}/bam"
    rclone_copy "${OG}/05-decontamination/omnic/${OG}_${asm_ver}.dual.mapped.PT.bam.bai" \
        "${OG}/${OG}_${asm_ver}/bam"
    rclone_copy "${OG}/05-decontamination/omnic/${OG}_${asm_ver}.dual.stats.txt" \
        "${OG}/${OG}_${asm_ver}/bam"
    rclone_copy "${OG}/05-decontamination/omnic/${OG}_${asm_ver}.hap1.mapped.PT.bam" \
        "${OG}/${OG}_${asm_ver}/bam"
    rclone_copy "${OG}/05-decontamination/omnic/${OG}_${asm_ver}.hap1.mapped.PT.bam.bai" \
        "${OG}/${OG}_${asm_ver}/bam"
    rclone_copy "${OG}/05-decontamination/omnic/${OG}_${asm_ver}.hic1.hap1.stats.txt" \
        "${OG}/${OG}_${asm_ver}/bam"
    rclone_copy "${OG}/05-decontamination/omnic/${OG}_${asm_ver}.hap2.mapped.PT.bam" \
        "${OG}/${OG}_${asm_ver}/bam"
    rclone_copy "${OG}/05-decontamination/omnic/${OG}_${asm_ver}.hap2.mapped.PT.bam.bai" \
        "${OG}/${OG}_${asm_ver}/bam"
    rclone_copy "${OG}/05-decontamination/omnic/${OG}_${asm_ver}.hic1.hap2.stats.txt" \
        "${OG}/${OG}_${asm_ver}/bam"

    # Decontamination QC
    rclone_copy "${OG}/05-decontamination/busco" \
        "${OG}/${OG}_${asm_ver}/busco"
    rclone_copy "${OG}/05-decontamination/gfastats" \
        "${OG}/${OG}_${asm_ver}/gfastats"
    rclone_copy "${OG}/05-decontamination/NCBI/out" \
        "${OG}/${OG}_${asm_ver}/decontamination/NCBI"
    rclone_copy "${OG}/05-decontamination/tiara" \
        "${OG}/${OG}_${asm_ver}/decontamination/tiara"
    rclone_copy "${OG}/05-decontamination/final-fastas/" \
        "${OG}/${OG}_${asm_ver}/assembly"

    # Coverage, telomere, pretext
    rclone_copy "${OG}/06-coverage-tracks/${OG}_${asm_ver}.dual.hap.gaps.bedgraph" \
        "${OG}/${OG}_${asm_ver}/bedgraph"
    rclone_copy "${OG}/06-coverage-tracks/${OG}_${asm_ver}.dual.hap.bedgraph" \
        "${OG}/${OG}_${asm_ver}/bedgraph"
    rclone_copy "${OG}/07-telomers" \
        "${OG}/${OG}_${asm_ver}/bedgraph"

    rclone_copy "${OG}/08-pretext/${OG}_${asm_ver}.2.tiara.dual.pretext_snapshotFullMap.png" \
        "${OG}/${OG}_${asm_ver}/pretext"
    rclone_copy "${OG}/08-pretext/${OG}_${asm_ver}.2.tiara.hap1.pretext_snapshotFullMap.png" \
        "${OG}/${OG}_${asm_ver}/pretext"
    rclone_copy "${OG}/08-pretext/${OG}_${asm_ver}.2.tiara.hap2.pretext_snapshotFullMap.png" \
        "${OG}/${OG}_${asm_ver}/pretext"
    rclone_copy "${OG}/08-pretext/${OG}_${asm_ver}.2.tiara.dual-hi-res.pretext" \
        "${OG}/${OG}_${asm_ver}/pretext"
    rclone_copy "${OG}/08-pretext/${OG}_${asm_ver}.2.tiara.hap1.pretext" \
        "${OG}/${OG}_${asm_ver}/pretext"
    rclone_copy "${OG}/08-pretext/${OG}_${asm_ver}.2.tiara.hap2.pretext" \
        "${OG}/${OG}_${asm_ver}/pretext"
    rclone_copy "${OG}/08-pretext/${OG}_${asm_ver}.2.tiara.dual.pretext" \
        "${OG}/${OG}_${asm_ver}/pretext"

    rclone_copy "${OG}/09-chromsyn/${OG}.hapsyn.pdf" \
        "${OG}/${OG}_${asm_ver}/chromsyn"

    rclone copy "${OG}/multiqc" \
        "pawsey0964:oceanomics-refassemblies/${OG}/${OG}_${asm_ver}/multiqc"

fi

# ═════════════════════════════════════════════════════════════════════════════
# MODE: single_hap  — Precomputed single-haplotype assembly
#   Dirs use -sh suffix to distinguish from dual-hap pipeline outputs.
# ═════════════════════════════════════════════════════════════════════════════
if [[ "$mode" == "single_hap" ]]; then

    # Assembly FASTA (gfastats-sh output — same naming as hap1 in hifi_hic)
    rclone_copy "${OG}/03-assembly/gfastats-sh/${OG}_${asm_ver}.1.hifiasm.hap1.assembly_summary.txt" \
        "${OG}/${OG}_${asm_ver}/gfastats"
    rclone_copy "${OG}/03-assembly/gfastats-sh/${OG}_${asm_ver}.1.hifiasm.hap1.fasta" \
        "${OG}/${OG}_${asm_ver}/assembly"

    # Merqury and BUSCO (contig-level)
    rclone_copy "${OG}/03-assembly/merqury-sh" \
        "${OG}/${OG}_${asm_ver}/merqury"
    rclone_copy "${OG}/03-assembly/busco-sh" \
        "${OG}/${OG}_${asm_ver}/busco"

    # OMNIC pre-scaffolding BAM (single hap)
    rclone_copy "${OG}/04-scaffolding/omnic-sh/${OG}_${asm_ver}.hap1.mapped.contigs.bam" \
        "${OG}/${OG}_${asm_ver}/bam"
    rclone_copy "${OG}/04-scaffolding/omnic-sh/${OG}_${asm_ver}.hap1.mapped.contigs.bam.bai" \
        "${OG}/${OG}_${asm_ver}/bam"

    # YAHS scaffold (single hap)
    rclone_copy "${OG}/04-scaffolding/yahs-sh/${OG}_${asm_ver}.2.yahs.hap1_scaffolds_final.fa" \
        "${OG}/${OG}_${asm_ver}/assembly"

    # OMNIC post-scaffolding BAM (single hap)
    rclone_copy "${OG}/05-decontamination/omnic-sh/${OG}_${asm_ver}.hap1.mapped.PT.bam" \
        "${OG}/${OG}_${asm_ver}/bam"
    rclone_copy "${OG}/05-decontamination/omnic-sh/${OG}_${asm_ver}.hap1.mapped.PT.bam.bai" \
        "${OG}/${OG}_${asm_ver}/bam"
    rclone_copy "${OG}/05-decontamination/omnic-sh/${OG}_${asm_ver}.hic1.hap1.stats.txt" \
        "${OG}/${OG}_${asm_ver}/bam"

    # Decontamination QC
    rclone_copy "${OG}/05-decontamination/busco-sh" \
        "${OG}/${OG}_${asm_ver}/busco"
    rclone_copy "${OG}/05-decontamination/gfastats-sh" \
        "${OG}/${OG}_${asm_ver}/gfastats"
    rclone_copy "${OG}/05-decontamination/NCBI-sh/out" \
        "${OG}/${OG}_${asm_ver}/decontamination/NCBI"
    rclone_copy "${OG}/05-decontamination/tiara-sh" \
        "${OG}/${OG}_${asm_ver}/decontamination/tiara"

    # Final renamed FASTA (from RENAME_SCAFFOLDS + BBMAP_FILTERBYNAME_SH)
    rclone_copy "${OG}/05-decontamination/final-fastas-sh/" \
        "${OG}/${OG}_${asm_ver}/assembly"

    # Coverage, telomere, pretext (use -sh pretext dir)
    rclone_copy "${OG}/06-coverage-tracks/${OG}_${asm_ver}.hap1.gaps.bedgraph" \
        "${OG}/${OG}_${asm_ver}/bedgraph"
    rclone_copy "${OG}/06-coverage-tracks/${OG}_${asm_ver}.hap1.bedgraph" \
        "${OG}/${OG}_${asm_ver}/bedgraph"
    rclone_copy "${OG}/07-telomers" \
        "${OG}/${OG}_${asm_ver}/bedgraph"

    rclone_copy "${OG}/08-pretext-sh/" \
        "${OG}/${OG}_${asm_ver}/pretext"

    rclone copy "${OG}/multiqc" \
        "pawsey0964:oceanomics-refassemblies/${OG}/${OG}_${asm_ver}/multiqc"

fi

echo "=== Backup complete for $OG ($asm_ver) [$mode] ==="
