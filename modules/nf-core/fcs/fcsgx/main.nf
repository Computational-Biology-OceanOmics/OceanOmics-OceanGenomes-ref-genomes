process FCS_FCSGX {
    tag "$meta.id"
    label 'process_low'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://ftp.ncbi.nlm.nih.gov/genomes/TOOLS/FCS/releases/0.5.5/fcs-gx.sif':
        'docker.io/ncbi/fcs-gx:0.5.5' }"

    input:
    tuple val(meta), path(assembly)
    path gxdb
    val(haplotype)

    output:
    tuple val(meta), path("out/*.fcs_gx_report.txt"), emit: fcs_gx_report
    tuple val(meta), path("out/*.taxonomy.rpt")     , emit: taxonomy_report
    path "versions.yml"                             , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error "FCS_FCSGX module does not support Conda. Please use Docker / Singularity / Podman instead."
    }
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def FCSGX_VERSION = '0.4.0'

    """
    echo 'copying database files to /tmp/'
    mkdir -p /tmp/gxdb/
    cp -v ${gxdb}/all.gxi /tmp/gxdb/
    cp -v ${gxdb}/all.gxs /tmp/gxdb/
    cp -v ${gxdb}/all.meta.jsonl /tmp/gxdb/
    cp -v ${gxdb}/all.blast_div.tsv.gz /tmp/gxdb/
    cp -v ${gxdb}/all.taxa.tsv /tmp/gxdb/
    echo 'done copying database files'
    ls -l /tmp/gxdb/


    cp `readlink ${assembly}` ${prefix}_copied_input.fasta

    python3 /app/bin/run_gx \\
        --fasta ${prefix}_copied_input.fasta \\
        --out-dir ./out \\
        --gx-db /tmp/gxdb \\
        --tax-id ${meta.taxid} \\
        --out-basename ${prefix}_${haplotype}.${meta.taxid} \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version 2>&1 | sed -e "s/Python //g")
        FCS-GX: $FCSGX_VERSION
    END_VERSIONS
    """

    stub:
    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error "FCS_FCSGX module does not support Conda. Please use Docker / Singularity / Podman instead."
    }
    def prefix = task.ext.prefix ?: "${meta.id}"
    def FCSGX_VERSION = '0.4.0'

    """
    mkdir -p out
    mkdir -p /tmp/gxdb/
    touch out/${prefix}_${haplotype}.${meta.taxid}.fcs_gx_report.txt
    touch out/${prefix}_${haplotype}.${meta.taxid}.taxonomy.rpt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version 2>&1 | sed -e "s/Python //g")
        FCS-GX: $FCSGX_VERSION
    END_VERSIONS
    """
}