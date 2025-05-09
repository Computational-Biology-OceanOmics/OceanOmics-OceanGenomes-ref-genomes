module load nextflow/24.04.3

<<<<<<< HEAD
nextflow run /scratch/pawsey0812/lhuet/OceanOmics-OceanGenomes-ref-genomes/main.nf -profile singularity --input assets/samplesheet.csv --outdir  /scratch/pawsey0812/lhuet/refgen --buscodb /scratch/references/busco_db/actinopterygii_odb10 --gxdb /scratch/references/Foreign_Contamination_Screening/gxdb --binddir /scratch -c pawsey_profile.config -resume --tempdir $MYSCRATCH
=======
nextflow run main.nf -profile singularity --input assets/samplesheet.csv --outdir  /scratch/pawsey0964/lhuet/ref-gen/re-run --buscodb /scratch/references/busco_db/actinopterygii_odb10 --gxdb /scratch/references/Foreign_Contamination_Screening/gxdb --binddir /scratch -c pawsey_profile.config -resume --tempdir /scratch/pawsey0964/lhuet/tmp
>>>>>>> dd2184d (updated scripts and containers and added mitohifi)
