module load nextflow/24.10.0
module load singularity/4.1.0-nompi

export NXF_HOME=/scratch/pawsey1348/olivianguyen/.nextflow_home

nextflow run main.nf \
    -profile singularity \
    --input /scratch/pawsey1348/olivianguyen/ref-gen/OceanOmics-OceanGenomes-ref-genomes/assets/samplesheet_20260722.csv \
    --outdir /scratch/pawsey1348/olivianguyen/ref-gen \
    --assembly_mode hifi_hic \
    --scaffolder yahs \
    --buscodb /scratch/pawsey0964/$USER/busco_db/actinopterygii_odb10 \
    --gxdb /scratch/references/Foreign_Contamination_Screening/gxdb \
    --binddir /scratch \
    -c pawsey_profile.config \
    -resume \
    --tempdir /scratch/pawsey1348/olivianguyen/ref-gen/tmp \
    --bs_config ~/.basespace/default.cfg \
    --sql_config ~/postgresql_details/oceanomics.cfg
