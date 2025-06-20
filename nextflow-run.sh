module load nextflow/24.04.3

nextflow run main.nf -profile singularity --input /scratch/pawsey0964/lhuet/refgenomes/OceanOmics-OceanGenomes-ref-genomes/assets/samplesheet.csv --outdir  /scratch/pawsey0964/lhuet/refgenomes --buscodb /scratch/references/busco_db/actinopterygii_odb10 --gxdb /scratch/references/Foreign_Contamination_Screening/gxdb --binddir /scratch -c pawsey_profile.config -resume --tempdir /scratch/pawsey0964/lhuet/refgenomes/tmp
