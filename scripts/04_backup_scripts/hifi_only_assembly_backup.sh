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
asm_ver=hifi1
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

### Back up hifiadaptfilt reads to fastq

rclone copy ${OG}/01-data-processing/hifiadaptfilt/${OG}_${date}.${asm_ver}/ pawsey0812:oceanomics-fastq/${OG}/hifi --checksum --progress


##back up kmer profilling (genomescope and meryl)
rclone copy ${OG}/02-kmer-profiling/genomescope2/ pawsey0812:oceanomics-assemblies/${OG}/genomescope --checksum --progress
rclone copy ${OG}/02-kmer-profiling/${OG}_${asm_ver}.meryldb.tar.gz/ pawsey0812:oceanomics-assemblies/${OG}/meryl --checksum --progress

#Back up hifiasm assemblies and gfa stats
# 1.Assemblies
rclone copy ${OG}/03-assembly/gfastats-hifi/${OG}_${date}.${asm_ver}.0.hifiasm.a_ctg.fasta  pawsey0812:oceanomics-assemblies/${OG}/${OG}_${date}.${asm_ver}/assembly --checksum --progress
rclone copy ${OG}/03-assembly/gfastats-hifi/${OG}_${date}.${asm_ver}.0.hifiasm.p_ctg.fasta pawsey0812:oceanomics-assemblies/${OG}/${OG}_${date}.${asm_ver}/assembly --checksum --progress
rclone copy ${OG}/03-assembly/hifi/${OG}_${date}.${asm_ver}.0.hifiasm.p_ctg.gfa pawsey0812:oceanomics-assemblies/${OG}/${OG}_${date}.${asm_ver}/assembly --checksum --progress
rclone copy ${OG}/03-assembly/hifi/${OG}_${date}.${asm_ver}.0.hifiasm.p_ctg.gfa pawsey0812:oceanomics-assemblies/${OG}/${OG}_${date}.${asm_ver}/assembly --checksum --progress

#gfastats 
rclone copy ${OG}/03-assembly/gfastats-hifi/${OG}_${date}.${asm_ver}.0.hifiasm.a_ctg.assembly_summary.txt pawsey0812:oceanomics-assemblies/${OG}/${OG}_${date}.${asm_ver}/gfastats --checksum --progress
rclone copy ${OG}/03-assembly/gfastats-hifi/${OG}_${date}.${asm_ver}.0.hifiasm.p_ctg.assembly_summary.txt pawsey0812:oceanomics-assemblies/${OG}/${OG}_${date}.${asm_ver}/gfastats --checksum --progress

