process TRIGGER_MITOGENOME {
    tag "trigger_mitogenome"
    
    input:
    val all_samples // Used to trigger this process after all samples are collected
    
    output:
    path "run_*.sh", emit: mito_run_script
    
    
script:
def input_pattern = "${params.outdir}/OG*/01-data-processing/hifiadaptfilt/OG*/*.fastq.gz"
"${params.outdir}/OG*/hic/*.fastq.gz" - these are the raw ones
"${params.outdir}/OG*/01-data-processing/fastp_hic/*.fastq.gz" - these are the filtered ones

maybe add in the collect for the hic and hifi as seperate ones and then these can just be ran as seperate mitogenome runs
    

"""
# Generate timestamp once
TIMESTAMP=\$(date +%y%m%d_%H%M%S)
SCRIPT_NAME="run_${params.run}_mitogenomes_\${TIMESTAMP}.sh"

cat > \$SCRIPT_NAME << 'EOF'
    module load nextflow/24.10.0
    module load singularity/4.1.0-nompi

    /scratch/pawsey0964/tpeirce/nextflow-24.10.5-dist -log \\\$(realpath ../mitogenomes/${params.run}_mitogenomes_\${TIMESTAMP}) \\
        run main.nf \\
        -work-dir ./work/${params.run}_mitogenomes_\${TIMESTAMP} \\
        -c pawsey_profile.config \\
        -resume \\
        -profile singularity \\
        -with-report \\
        --input_dir \"${input_pattern}\" \\
        --outdir \\\$(realpath ../mitogenomes/${params.run}_mitogenomes_\${TIMESTAMP}) \\
        --blast_db_dir \\\$(realpath ../blast_dbs) \\
        --taxonkit_db_dir \\\$(realpath ../) \\
        --curated_blast_db /scratch/pawsey0964/pbayer/OceanGenomes.CuratedNT.NBDLTranche1and2.CuratedBOLD.fasta \\
        --organelle_type \"animal_mt\" \\
        --kvalue \"21\" \\
        --bs_config ~/.basespace/default.cfg \\
        --sql_config "${params.sql_config}" \\
        --binddir /scratch \\
        --tempdir /scratch/pawsey0964/tpeirce/tmp \\
        --refresh-modules \\
        --skip_mitogenome_assembly_getorg false \\
        --skip_mitogenome_assembly_hifi false \\
        --skip_mitogenome_annotation false \\
        --skip_upload_results false \\
        --samplesheet_prefix \"samplesheet\" \\
        --template_sbt \"/home/tpeirce/template.sbt\" \\
        --translation_table \"2\"
    EOF
    chmod +x \$SCRIPT_NAME
"""
}