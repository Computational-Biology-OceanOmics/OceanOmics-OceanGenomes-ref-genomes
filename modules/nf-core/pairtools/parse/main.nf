process PAIRTOOLS_PARSE {
    tag "$meta.id"
    label 'process_low'

    // Pinning numpy to 1.23 until https://github.com/open2c/pairtools/issues/170 is resolved
    // Not an issue with the biocontainers because they were built prior to numpy 1.24
   // conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker.io/sawtooth01/pairtools:v1.1.0': 
        'biocontainers/pairtools:1.1.0--py310hb45ccb3_0' }"

    input:
    tuple val(meta), path(sam), path(chromsizes)
    val(tempdir)

    output:
    tuple val(meta), path("*.pairsam")  , emit: pairsam
    tuple val(meta), path("*.pairsam.stat"), emit: stat
    path "versions.yml"                    , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    export PATH=$PATH:/opt/conda/envs/pairtools/bin
    pairtools \\
        parse \\
        -c $chromsizes \\
        $args \\
        --output-stats ${prefix}.pairsam.stat \\
        -o ${prefix}.pairsam \\
        $sam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pairtools: \$(pairtools --version 2>&1 | tr '\\n' ',' | sed 's/.*pairtools.*version //' | sed 's/,\$/\\n/')
    END_VERSIONS
    """
}
