module load nextflow/23.10.0

nextflow run /scratch/pawsey0812/lhuet/OceanGenomes-refgenomes/main.nf -profile singularity --input samplesheet.csv --outdir  /scratch/pawsey0812/lhuet/HIFI_ONLY --buscodb /scratch/references/busco_db/actinopterygii_odb10 --gxdb /scratch/references/Foreign_Contamination_Screening/gxdb --rclonedest huet --binddir /scratch -c pawsey_profile.config -resume --tempdir $MYSCRATCH