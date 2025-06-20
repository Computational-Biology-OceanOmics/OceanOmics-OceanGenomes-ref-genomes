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
#Loading the required modules

OG=$1
date=$2
version=$3
asm_ver=$date.$version
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

# Tar kmer directories
rm -f success
tar -czvf ${OG}/02-kmer-profiling/meryl/${OG}_${asm_ver}.meryldb.tar.gz -C ${OG}/02-kmer-profiling/meryl ${OG}_${asm_ver}.meryldb && touch success

wait

# Remove only if tar was successful and the file exists
if [[ -f success ]]; then
  target_dir="${OG}/02-kmer-profiling/meryl/${OG}_${asm_ver}.meryldb"
  if [[ -d $target_dir ]]; then
    rm -rf "$target_dir"
    echo "Removed directory: $target_dir"
  else
    echo "Error: Target directory $target_dir does not exist. Skipping removal."
  fi
fi

##back up kmer profilling (genomescope and meryl)
#rclone copy ${OG}/02-kmer-profiling/genomescope2/ pawsey0812:oceanomics-assemblies/${OG}/genomescope --checksum --progress
rclone copy ${OG}/02-kmer-profiling/meryl/ pawsey0812:oceanomics-assemblies/${OG}/meryl --checksum --progress

#Back up hifiasm assemblies and qc (gfa stats, merqury, BUSCO)
# 1.Assemblies
rclone copy ${OG}/03-assembly/gfastats/${OG}_${asm_ver}.0.hifiasm.hap1.fasta  pawsey0812:oceanomics-assemblies/${OG}/${OG}_${asm_ver}/assembly --checksum --progress
rclone copy ${OG}/03-assembly/gfastats/${OG}_${asm_ver}.0.hifiasm.hap2.fasta pawsey0812:oceanomics-assemblies/${OG}/${OG}_${asm_ver}/assembly --checksum --progress
rclone copy ${OG}/03-assembly/hifiasm/${OG}_${asm_ver}.hic.hap1.p_ctg.gfa pawsey0812:oceanomics-assemblies/${OG}/${OG}_${asm_ver}/assembly --checksum --progress
rclone copy ${OG}/03-assembly/hifiasm/${OG}_${asm_ver}.hic.hap2.p_ctg.gfa pawsey0812:oceanomics-assemblies/${OG}/${OG}_${asm_ver}/assembly --checksum --progress

#gfastats 
rclone copy ${OG}/03-assembly/hifiasm/gfastats/${OG}_${asm_ver}.0.hifiasm.hap1.assembly_summary.txt pawsey0812:oceanomics-assemblies/${OG}/${OG}_${asm_ver}/gfastats --checksum --progress
rclone copy ${OG}/03-assembly/hifiasm/gfastats/${OG}_${asm_ver}.0.hifiasm.hap2.assembly_summary.txt pawsey0812:oceanomics-assemblies/${OG}/${OG}_${asm_ver}/gfastats --checksum --progress

#gfastats hifi only 
#rclone copy ${OG}/03-assembly/hifiasm/gfastats/${OG}_${asm_ver}.0.hifiasm.a_ctg.assembly_summary.txt pawsey0812:oceanomics-assemblies/${OG}/${OG}_${asm_ver}/gfastats --checksum --progress
#rclone copy ${OG}/03-assembly/hifiasm/gfastats/${OG}_${asm_ver}.0.hifiasm.p_ctg.fasta pawsey0812:oceanomics-assemblies/${OG}/${OG}_${asm_ver}/gfastats --checksum --progress

#merqury 
rclone copy ${OG}/03-assembly/merqury pawsey0812:oceanomics-assemblies/${OG}/${OG}_${asm_ver}/merqury --checksum --progress

# Busco 
rclone copy ${OG}/03-assembly/busco pawsey0812:oceanomics-assemblies/${OG}/${OG}_${asm_ver}/busco --checksum --progress

#Back up hifi-hic scaffolded bam files from OMNIC pipeline

rclone copy ${OG}/04-scaffolding/omnic/${OG}_${asm_ver}.hap1.hic.mapped.contigs.bam pawsey0812:oceanomics-assemblies/${OG}/${OG}_${asm_ver}/bam --checksum --progress
rclone copy ${OG}/04-scaffolding/omnic/${OG}_${asm_ver}.hap1.hic.mapped.contigs.bam.bai pawsey0812:oceanomics-assemblies/${OG}/${OG}_${asm_ver}/bam --checksum --progress

rclone copy ${OG}/04-scaffolding/omnic/${OG}_${asm_ver}.hap2.hic.mapped.contigs.bam pawsey0812:oceanomics-assemblies/${OG}/${OG}_${asm_ver}/bam --checksum --progress
rclone copy ${OG}/04-scaffolding/omnic/${OG}_${asm_ver}.hap2.hic.mapped.contigs.bam.bai pawsey0812:oceanomics-assemblies/${OG}/${OG}_${asm_ver}/bam --checksum --progress

# back up hifi-hic scaffolds from curation prep pipeline 

rclone copy ${OG}/05-decontamination/omnic/${OG}_${asm_ver}.dual.mapped.PT.bam pawsey0812:oceanomics-assemblies/${OG}/${OG}_${asm_ver}/bam --checksum --progress
rclone copy ${OG}/05-decontamination/omnic/${OG}_${asm_ver}.dual.mapped.PT.bam.bai pawsey0812:oceanomics-assemblies/${OG}/${OG}_${asm_ver}/bam --checksum --progress
rclone copy ${OG}/05-decontamination/omnic/${OG}_${asm_ver}.dual.stats.txt pawsey0812:oceanomics-assemblies/${OG}/${OG}_${asm_ver}/bam --checksum --progress

rclone copy ${OG}/05-decontamination/omnic/${OG}_${asm_ver}.hap1.mapped.PT.bam pawsey0812:oceanomics-assemblies/${OG}/${OG}_${asm_ver}/bam --checksum --progress
rclone copy ${OG}/05-decontamination/omnic/${OG}_${asm_ver}.hap1.mapped.PT.bam.bai pawsey0812:oceanomics-assemblies/${OG}/${OG}_${asm_ver}/bam --checksum --progress
rclone copy ${OG}/05-decontamination/omnic/${OG}_${asm_ver}.hic1.hap1.stats.txt pawsey0812:oceanomics-assemblies/${OG}/${OG}_${asm_ver}/bam --checksum --progress

rclone copy ${OG}/05-decontamination/omnic/${OG}_${asm_ver}.hap2.mapped.PT.bam pawsey0812:oceanomics-assemblies/${OG}/${OG}_${asm_ver}/bam --checksum --progress
rclone copy ${OG}/05-decontamination/omnic/${OG}_${asm_ver}.hap2.mapped.PT.bam.bai pawsey0812:oceanomics-assemblies/${OG}/${OG}_${asm_ver}/bam --checksum --progress
rclone copy ${OG}/05-decontamination/omnic/${OG}_${asm_ver}.hic1.hap2.stats.txt pawsey0812:oceanomics-assemblies/${OG}/${OG}_${asm_ver}/bam --checksum --progress



# back up YAHS scaffoled files

rclone copy ${OG}/04-scaffolding/yahs/${OG}_${asm_ver}.1.yahs.hap1_scaffolds_final.fa pawsey0812:oceanomics-assemblies/${OG}/${OG}_${asm_ver}/assembly --checksum --progress
rclone copy ${OG}/04-scaffolding/yahs/${OG}_${asm_ver}.1.yahs.hap2_scaffolds_final.fa pawsey0812:oceanomics-assemblies/${OG}/${OG}_${asm_ver}/assembly --checksum --progress


# Back up decontamination results and QC stats

rclone copy ${OG}/05-decontamination/busco pawsey0812:oceanomics-assemblies/${OG}/${OG}_${asm_ver}/busco --checksum --progress
rclone copy ${OG}/05-decontamination/gfastats pawsey0812:oceanomics-assemblies/${OG}/${OG}_${asm_ver}/gfastats --checksum --progress

rclone copy ${OG}/05-decontamination/NCBI/out pawsey0812:oceanomics-assemblies/${OG}/${OG}_${asm_ver}/decontamination/NCBI --checksum --progress
rclone copy ${OG}/05-decontamination/tiara pawsey0812:oceanomics-assemblies/${OG}/${OG}_${asm_ver}/decontamination/tiara --checksum --progress

#final decontaminated fasta
rclone copy ${OG}/05-decontamination/final-fastas/ pawsey0812:oceanomics-assemblies/${OG}/${OG}_${asm_ver}/assembly --checksum --progress

## back up coverage tracks, bedgraph files

rclone copy ${OG}/06-coverage-tracks/${OG}_${asm_ver}.dual.hap.gaps.bedgraph pawsey0812:oceanomics-assemblies/${OG}/${OG}_${asm_ver}/bedgraph --checksum --progress
rclone copy ${OG}/06-coverage-tracks/${OG}_${asm_ver}.dual.hap.bedgraph pawsey0812:oceanomics-assemblies/${OG}/${OG}_${asm_ver}/bedgraph --checksum --progress
rclone copy ${OG}/07-telomers/${OG}_${asm_ver}_sorted_telomeric_locations.bedgraph pawsey0812:oceanomics-assemblies/${OG}/${OG}_${asm_ver}/bedgraph --checksum --progress

# back up pretext snapshots and maps
rclone copy ${OG}/08-pretext/${OG}_${asm_ver}.2.tiara.dual.pretext_snapshotFullMap.png pawsey0812:oceanomics-assemblies/${OG}/${OG}_${asm_ver}/pretext --checksum --progress
rclone copy ${OG}/08-pretext/${OG}_${asm_ver}.2.tiara.hap1.pretext_snapshotFullMap.png pawsey0812:oceanomics-assemblies/${OG}/${OG}_${asm_ver}/pretext --checksum --progress
rclone copy ${OG}/08-pretext/${OG}_${asm_ver}.2.tiara.hap2.pretext_snapshotFullMap.png pawsey0812:oceanomics-assemblies/${OG}/${OG}_${asm_ver}/pretext --checksum --progress


rclone copy ${OG}/08-pretext/${OG}_${asm_ver}.2.tiara.dual-hi-res.pretext pawsey0812:oceanomics-assemblies/${OG}/${OG}_${asm_ver}/pretext --checksum --progress
rclone copy ${OG}/08-pretext/${OG}_${asm_ver}.2.tiara..hap1.pretext pawsey0812:oceanomics-assemblies/${OG}/${OG}_${asm_ver}/pretext --checksum --progress
rclone copy ${OG}/08-pretext/${OG}_${asm_ver}.2.tiara.hap2.pretext pawsey0812:oceanomics-assemblies/${OG}/${OG}_${asm_ver}/pretext --checksum --progress


#back up chromsyn plot

rclone copy ${OG}/09-chromsyn/${OG}.hapsyn.pdf pawsey0812:oceanomics-assemblies/${OG}/${OG}_${asm_ver}/chromsyn --checksum --progress

# Back up multiqc report

rclone copy ${OG}/multiqc pawsey0812:oceanomics-assemblies/${OG}/${OG}_${asm_ver}/multiqc

# Backing up mitogenome results

rclone copy ${OG}/01-data-processing/mtdna/MitoReference pawsey0812:oceanomics-mitogenomes/${OG}/${OG}.hifi.${date}.v3mitohifi/mtdna/MitoReference/ --checksum --progress
rclone copy ${OG}/01-data-processing/mtdna/final_mitogenome.fasta pawsey0812:oceanomics-mitogenomes/${OG}/${OG}.hifi.${date}.v3mitohifi/mtdna/${OG}.hifi.${date}.v3mitohifi.fasta --checksum --progress
rclone copy ${OG}/01-data-processing/mtdna/contigs_circularization/all_contigs.circularisationCheck.txt pawsey0812:oceanomics-mitogenomes/${OG}/${OG}.hifi.${date}.v3mitohifi/mtdna/ --checksum --progress
rclone copy ${OG}/01-data-processing/mtdna/final_mitogenome_choice/all_mitogenomes.rotated.fa pawsey0812:oceanomics-mitogenomes/${OG}/${OG}.hifi.${date}.v3mitohifi/mtdna/ --checksum --progress
rclone copy ${OG}/01-data-processing/mtdna/contigs_stats.tsv pawsey0812:oceanomics-mitogenomes/${OG}/${OG}.hifi.${date}.v3mitohifi/mtdna/ --checksum --progress
rclone copy ${OG}/01-data-processing/mtdna/coverage_mapping/ pawsey0812:oceanomics-mitogenomes/${OG}/${OG}.hifi.${date}.v3mitohifi/mtdna/coverage_mapping/ --checksum --progress
rclone copy ${OG}/01-data-processing/mtdna/coverage_plot.png pawsey0812:oceanomics-mitogenomes/${OG}/${OG}.hifi.${date}.v3mitohifi/mtdna/ --checksum --progress
rclone copy ${OG}/01-data-processing/mtdna/final_mitogenome.coverage.png pawsey0812:oceanomics-mitogenomes/${OG}/${OG}.hifi.${date}.v3mitohifi/mtdna/ --checksum --progress
rclone copy ${OG}/01-data-processing/mtdna/contigs_annotations.png pawsey0812:oceanomics-mitogenomes/${OG}/${OG}.hifi.${date}.v3mitohifi/mtdna/mtdnaannotation/ --checksum --progress
rclone copy ${OG}/01-data-processing/mtdna/final_mitogenome.annotation.png pawsey0812:oceanomics-mitogenomes/${OG}/${OG}.hifi.${date}.v3mitohifi/mtdna/mtdnaannotation/ --checksum --progress
rclone copy ${OG}/01-data-processing/mtdna/final_mitogenome.gb pawsey0812:oceanomics-mitogenomes/${OG}/${OG}.hifi.${date}.v3mitohifi/mtdna/mtdnaannotation/ --checksum --progress
 

# Backing up LCA results
rclone copy ${OG}/01-data-processing/mtdna/lca/blast.12s.${OG}.hifi.${date}.v3mitohifi.emma102.filtered.tsv pawsey0812:oceanomics-mitogenomes/${OG}/${OG}.hifi.${date}.v3mitohifi/lca --checksum --progress
rclone copy ${OG}/01-data-processing/mtdna/lca/blast.16s.${OG}.hifi.${date}.v3mitohifi.emma102.filtered.tsv pawsey0812:oceanomics-mitogenomes/${OG}/${OG}.hifi.${date}.v3mitohifi/lca --checksum --progress
rclone copy ${OG}/01-data-processing/mtdna/lca/blast.CO1.${OG}.hifi.${date}.v3mitohifi.emma102.filtered.tsv pawsey0812:oceanomics-mitogenomes/${OG}/${OG}.hifi.${date}.v3mitohifi/lca --checksum --progress
rclone copy ${OG}/01-data-processing/mtdna/lca/lca.12s.${OG}.hifi.${date}.v3mitohifi.emma102.tsv pawsey0812:oceanomics-mitogenomes/${OG}/${OG}.hifi.${date}.v3mitohifi/lca --checksum --progress
rclone copy ${OG}/01-data-processing/mtdna/lca/lca.16s.${OG}.hifi.${date}.v3mitohifi.emma102.tsv pawsey0812:oceanomics-mitogenomes/${OG}/${OG}.hifi.${date}.v3mitohifi/lca --checksum --progress
rclone copy ${OG}/01-data-processing/mtdna/lca/lca.CO1.${OG}.hifi.${date}.v3mitohifi.emma102.tsv pawsey0812:oceanomics-mitogenomes/${OG}/${OG}.hifi.${date}.v3mitohifi/lca --checksum --progress

#backing up emma 
rclone copy ${OG}/01-data-processing/mtdna/emma/${OG}.hifi.${date}.v3mitohifi.emma102.svg pawsey0812:oceanomics-mitogenomes/${OG}/${OG}.hifi.${date}.v3mitohifi/emma --checksum --progress
rclone copy ${OG}/01-data-processing/mtdna/emma/${OG}.hifi.${date}.v3mitohifi.emma102.fa pawsey0812:oceanomics-mitogenomes/${OG}/${OG}.hifi.${date}.v3mitohifi/emma --checksum --progress
rclone copy ${OG}/01-data-processing/mtdna/emma/${OG}.hifi.${date}.v3mitohifi.emma102.fa.gff pawsey0812:oceanomics-mitogenomes/${OG}/${OG}.hifi.${date}.v3mitohifi/emma --checksum --progress
rclone copy ${OG}/01-data-processing/mtdna/emma/${OG}.hifi.${date}.v3mitohifi.emma102.tbl pawsey0812:oceanomics-mitogenomes/${OG}/${OG}.hifi.${date}.v3mitohifi/emma --checksum --progress


#backing up CDS
rclone copy ${OG}/01-data-processing/mtdna/emma/cds/MT-CO1.${OG}.hifi.240520.v3mitohifi.emma102.fa pawsey0812:oceanomics-mitogenomes/${OG}/${OG}.hifi.${date}.v3mitohifi/emma/cds --checksum --progress
rclone copy ${OG}/01-data-processing/mtdna/emma/cds/MT-RNR1.${OG}.hifi.240520.v3mitohifi.emma102.fa pawsey0812:oceanomics-mitogenomes/${OG}/${OG}.hifi.${date}.v3mitohifi/emma/cds --checksum --progress
rclone copy ${OG}/01-data-processing/mtdna/emma/cds/MT-RNR2.${OG}.hifi.240520.v3mitohifi.emma102.fa pawsey0812:oceanomics-mitogenomes/${OG}/${OG}.hifi.${date}.v3mitohifi/emma/cds --checksum --progress




