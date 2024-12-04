#!/bin/bash --login
#SBATCH --account=pawsey0812
#SBATCH --job-name=ocean-genomes
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
asmv=hifi1

### Back up hifiadaptfilt reads to fastq

rclone copy ${OG}/01-data-processing/hifiadaptfilt/${OG}_${date}.${asmv}/ pawsey0812:oceanomics-fastq/${OG}/hifi --checksum --progress


##back up kmer profilling (genomescope and meryl)
rclone copy ${OG}/02-kmer-profiling/genomescope2/ pawsey0812:oceanomics-assemblies/${OG}/genomescope --checksum --progress
#rclone copy ${OG}/02-kmer-profiling/meryl/ pawsey0812:oceanomics-assemblies/${OG}/meryl --checksum --progress

#Back up hifiasm assemblies and gfa stats
# 1.Assemblies
rclone copy ${OG}/03-assembly/gfastats-hifi/${OG}_${date}.${asmv}.0.hifiasm.a_ctg.fasta  pawsey0812:oceanomics-assemblies/${OG}/${OG}_${date}.${asmv}/assembly --checksum --progress
rclone copy ${OG}/03-assembly/gfastats-hifi/${OG}_${date}.${asmv}.0.hifiasm.p_ctg.fasta pawsey0812:oceanomics-assemblies/${OG}/${OG}_${date}.${asmv}/assembly --checksum --progress
rclone copy ${OG}/03-assembly/hifi/${OG}_${date}.${asmv}.0.hifiasm.p_ctg.gfa pawsey0812:oceanomics-assemblies/${OG}/${OG}_${date}.${asmv}/assembly --checksum --progress
rclone copy ${OG}/03-assembly/hifi/${OG}_${date}.${asmv}.0.hifiasm.a_ctg.gfa pawsey0812:oceanomics-assemblies/${OG}/${OG}_${date}.${asmv}/assembly --checksum --progress

#gfastats 
rclone copy ${OG}/03-assembly/gfastats-hifi/${OG}_${date}.${asmv}.0.hifiasm.a_ctg.assembly_summary.txt pawsey0812:oceanomics-assemblies/${OG}/${OG}_${date}.${asmv}/gfastats --checksum --progress
rclone copy ${OG}/03-assembly/gfastats-hifi/${OG}_${date}.${asmv}.0.hifiasm.p_ctg.assembly_summary.txt pawsey0812:oceanomics-assemblies/${OG}/${OG}_${date}.${asmv}/gfastats --checksum --progress

