process SAMTOOLS_FAIDX {
    tag "$fasta"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://quay.io/biocontainers/samtools:1.21--h96c455f_1' :
        'biocontainers/samtools:1.19.2--h50ea8bc_0' }"

    input:
    tuple val(meta), path(fasta)
    tuple val(meta2), path(fai)

    output:
    tuple val(meta), path ("*.{fa,fasta}") , emit: fa , optional: true
    tuple val(meta), path ("*.fai")        , emit: fai, optional: true
    //tuple val(meta), path ("*.gzi")        , emit: gzi, optional: true
    path "versions.yml"                    , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    samtools \\
        faidx \\
        ${fasta} \\
        $args

    # // rm \$fasta
    # // mv \${fasta}.fai ${fasta}.fai

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
    END_VERSIONS
    """

    stub:
    def match = (task.ext.args =~ /-o(?:utput)?\s(.*)\s?/).findAll()
    def fastacmd = match[0] ? "touch ${match[0][1]}" : ''
    """
    ${fastacmd}
    touch ${fasta}.fai

    cat <<-END_VERSIONS > versions.yml

    "${task.process}":
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
    END_VERSIONS
    """
}
