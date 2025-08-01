#!/bin/bash --login

#---------------
#chromsyn.sh: synteny between hap1/hap2 +/- a reference

#---------------
#Requested resources:
#SBATCH --account=pawsey0812
#SBATCH --job-name=chromsyn
#SBATCH --partition=work

#SBATCH --ntasks=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=48
#SBATCH --time=05:00:00
#SBATCH --mem=96G

#SBATCH --export=ALL
#SBATCH --output=%x-%j.out
#SBATCH --error=%x-%j.err

date=$(date +%y%m%d)

echo "========================================="
echo "SLURM_JOB_ID = $SLURM_JOB_ID"
echo "SLURM_NODELIST = $SLURM_NODELIST"
echo "DATE: $date"
echo "========================================="



#---------------
# Define variables
sample=$1
seq_date=$2
asm_ver=$3
ver="${seq_date}.${asm_ver}"
busco_db=actinopterygii_odb10

# Define paths
RUNDIR=$(pwd)
LPATH=/scratch/pawsey0964/lhuet/busco_db
SLIMSUITE=/software/projects/pawsey0812/rjedwards/slimsuite

echo "sample: $sample"
echo "seq_date: $seq_date"
echo "ver: $ver"
echo "BUSCO database: $busco_db"

#---------------
# Move and rename assemblies
echo "Copying final assemblies to chromsyn directory... "
cp ../05-decontamination/final-fastas/${sample}_${ver}.hap1.scaffolds_1.fa .
cp ../05-decontamination/final-fastas/${sample}_${ver}.hap2.scaffolds_2.fa .

#---------------
# Run compleasm
mkdir $RUNDIR/compleasm; cd $RUNDIR/compleasm

for GENOME in ../*.fa; do
  GENBASE=$(basename ${GENOME/.fa/})
  RUN=run_$GENBASE
  echo "Processing $GENOME with run name $RUN"

  # Run Compleasm
  if [ ! -f "$RUN/run_$busco_db/full_table.tsv" ]; then
    singularity run $SING/compleasm:0.2.6.sif compleasm run -a $GENOME -o $RUN -t 96 -l $busco_db -L $LPATH
    
    # Cleanup Compleasm
    cp -v $RUN/summary.txt $GENBASE.$busco_db.summary.txt
    cp -v $RUN/$busco_db/full_table.tsv $GENBASE.$busco_db.compleasm.tsv
    cp -v $RUN/$busco_db/full_table_busco_format.tsv $GENBASE.$busco_db.full_table.tsv
    rm -rf $RUN/$busco_db/hmmer_output
    
    for RATING in Single Duplicated Fragmented; do
      echo -e "SeqName\tStart\tEnd\tStrand\tBuscoID" | tee $GENBASE.$busco_db.$RATING.tsv
      awk -v rating="$RATING" '$2 == rating {print $3"\t"$4"\t"$5"\t"$6"\t"$1;}' $GENBASE.$busco_db.compleasm.tsv | tee -a $GENBASE.$busco_db.$RATING.tsv | tail
    done
  fi
done

#---------------
# Run barrnap (rDNA)
mkdir $RUNDIR/rdna; cd $RUNDIR/rdna

for GENOME in ../*.fa; do
  PREFIX=$(basename "${GENOME/.fa/}")
  if [ ! -f "$PREFIX.full.ctg.txt" ]; then
    # Replace the first four bases with GATC
    sed 's/^[ACGT][ACGT][ACGT][ACGT]/GATC/' "$GENOME" > "$PREFIX.tmp.fasta"
    # Predict rRNA sequences using Barrnap
    singularity run "$SING/barrnap:0.9.sif" barrnap --kingdom euk -o "$PREFIX.rrna.fa" --threads 16 < "$PREFIX.tmp.fasta" | tee "$PREFIX.rrna.gff"
    # Remove temporary file
    rm -v "$PREFIX.tmp.fasta"
    # Filter out 5S and partial sequences
    grep -v "5S" "$PREFIX.rrna.gff" | grep -v "partial" | tee "$PREFIX.rdna.gff"
    # Create a file to mark full-length rDNA repeats
    touch "$PREFIX.full.ctg.txt"
    # Find full-length rDNA repeats for each type
    for S in 5.8 18 28; do
      echo "$PREFIX ${S}S => $(grep "${S}S" "$PREFIX.rrna.gff" | grep -v "partial" | awk '{print $1;}' | sort | uniq -c )" | tee -a "$PREFIX.full.ctg.txt"
    done
    # Create a CSV file for ChromSyn
    echo "SeqName,Start,End,Strand,Col,Shape" | tee "$PREFIX.rrna.csv"
    # Generate feature file for ChromSyn
    grep RNA "$PREFIX.rrna.gff" | grep -v "partial" | sed 's/=/ /g' | awk '{print $1,$4,$5,$7,$11;}' | sed "s/ /,/g" | sed 's/5S/"white",23/' | sed 's/5.8S/"pink",22/' | sed 's/18S/"skyblue",24/' | sed 's/28S/"seagreen",25/' | tee -a "$PREFIX.rrna.csv"
  fi
done

#---------------
# Run Telociraptor and TIDK
mkdir $RUNDIR/gendata; cd $RUNDIR/gendata

for GENOME in ../*.fa; do
  GENBASE=$(basename "${GENOME/.fa/}")
  if [ ! -f "$GENBASE.tidk.tsv" ]; then
    singularity run "$SING/depthsizer:v1.9.0.sif" python "$SLIMSUITE/tools/telociraptor.py" tweak=F seqin="$GENOME" basefile="$GENBASE" i=-1 backups=F telonull=T
    singularity run "$SING/depthsizer:v1.9.0.sif" python "$SLIMSUITE/tools/telociraptor.py" tweak=T seqin="$GENOME" basefile="$GENBASE" i=-1 backups=F log="$GENBASE.tweak"
    singularity run "$SING/tidk:0.2.31.sif" tidk search -o "$GENBASE" -s AACCCT -d ./ -e tsv "$GENOME"
    awk '$3 > 9 || $4 > 9' "${GENBASE}_telomeric_repeat_windows.tsv" > "$GENBASE.tidk.tsv"
  fi
  cp -v "../rdna/$GENBASE.rrna.csv" "$GENBASE.ft.csv"
  cp -v "../compleasm/$GENBASE.$busco_db.full_table.tsv" .
done

# ---------------
# Make FOFN files
cd "$RUNDIR"/gendata

# Define variables
H1=$(basename ../*hap1*fa)
ABASE=$(echo "$H1" | awk -F '.hap1' '{print $1;}')
echo "$sample $ABASE"

# Generate FOFN files for various extensions
generate_fofn() {
    EXT=$1
    ls *.$EXT | awk '{print $1 " gendata/" $1}' | sed "s/\.$EXT//" | sed "s/$ABASE/$sample/" | tee ../"$2".fofn
}

EXT=$busco_db.full_table.tsv; ls *.$EXT | awk '{print $1 " gendata/" $1;}' | sed "s/\.$EXT//" | sed "s/$ABASE/$sample/" | tee ../busco.fofn
generate_fofn "gaps.tdt" "gaps"
generate_fofn "telomeres.tdt" "sequences"
generate_fofn "tidk.tsv" "tidk"
generate_fofn "ft.csv" "ft"

# ---------------
# Run ChromSyn
cd $RUNDIR
SETTINGS="pdfwidth=40 orphans=FALSE minregion=0 minbusco=3 ticks=1e7"
singularity run $SING/depthsizer:v1.9.0.sif Rscript $SLIMSUITE/libraries/r/chromsyn.R $SETTINGS basefile=$sample.hapsyn | tee $sample.hapsyn.log

# ---------------
# Backup image to Acacia
rclone copy $sample.hapsyn.pdf pawsey0964:oceanomics-refassemblies/${sample}/${sample}_${ver}/chromsyn