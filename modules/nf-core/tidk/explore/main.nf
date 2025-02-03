process TIDK_EXPLORE {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://quay.io/biocontainers/tidk:0.2.1--h87f3376_1':
        'biocontainers/tidk:0.2.41--hdbdd923 _0' }"

    input:
    tuple val(meta), path(cat_file)

    output:
    tuple val(meta), path("*sorted_telomeric_locations.bedgraph") , emit: telomer_sorted
    path "versions.yml"                         , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    tidk \\
        explore \\
        $args \\
        $cat_file \\
        > ${prefix}.telomeric_locations.bedgraph


    sort -k1,1 -k2,2n -o "${prefix}_sorted_telomeric_locations.bedgraph" "${prefix}.telomeric_locations.bedgraph"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        tidk: \$(tidk --version | sed 's/tidk //')
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.tidk.explore.tsv
    touch ${prefix}.top.sequence.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        tidk: \$(tidk --version | sed 's/tidk //')
    END_VERSIONS
    """
}
