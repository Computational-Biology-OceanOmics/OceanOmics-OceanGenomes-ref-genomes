
process FCSGX_CLEANGENOME {
    tag "$meta.id"
    label 'process_low'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
<<<<<<< HEAD
        'https://ftp.ncbi.nlm.nih.gov/genomes/TOOLS/FCS/releases/0.4.0/fcs-gx.sif':
        'docker.io/ncbi/fcs-gx:0.4.0' }"
=======
        'https://depot.galaxyproject.org/singularity/ncbi-fcs-gx:0.5.5--h9948957_0':
        'docker.io/ncbi/fcs-gx:0.5.5' }"
>>>>>>> dd2184d (updated scripts and containers and added mitohifi)

    input:
    tuple val(meta), path(fasta), path(fcsgx_report)

    output:
    tuple val(meta), path("*.cleaned.fasta")     , emit: cleaned
    tuple val(meta), path("*.contaminants.fasta"), emit: contaminants
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    gx clean-genome \\
        --input ${fasta} \\
        --action-report ${fcsgx_report} \\
        --output ${prefix}.cleaned.fasta \\
        --contam-fasta-out ${prefix}.contaminants.fasta \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fcsgx: \$( gx --help | sed '/build/!d; s/.*:v//; s/-.*//' )
    END_VERSIONS
    """

    stub:
    // def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.cleaned.fasta
    touch ${prefix}.contaminants.fasta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fcsgx: \$( gx --help | sed '/build/!d; s/.*:v//; s/-.*//' )
    END_VERSIONS
    """
}
