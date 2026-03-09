process BBMAP_FILTERBYNAME {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/bbmap:39.06--h92535d8_1' :
        'biocontainers/bbmap:39.06--h92535d8_1' }"

    input:
    tuple val(meta), path(fasta), path(contig_removal)
    val(suffix)

    output:
    tuple val(meta), path("*_scaffolds.fa")         , emit: scaffolds
    path  "versions.yml"                            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    filterbyname.sh \\
        in="$fasta" \\
        out="${prefix}.${suffix}_scaffolds.fa" \\
        names="$contig_removal" \\
        exclude \\
        $args

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bbmap: \$(bbversion.sh | grep -v "Duplicate cpuset")
    END_VERSIONS
    """
}
