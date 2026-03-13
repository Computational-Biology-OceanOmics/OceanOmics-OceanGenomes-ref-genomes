process BEDTOOLS_GENOMECOV {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/bedtools_coreutils:ba273c06a3909a15':
        'community.wave.seqera.io/library/bedtools_coreutils:a623c13f66d5262b' }"
 
    input:
    tuple val(meta), path(bam)
    val   extension

    output:
    tuple val(meta), path("*.dual.hap.bedgraph"), emit: genomecov
    tuple val(meta), path("*.dual.hap.gaps.bedgraph"), emit: gaps
    path  "versions.yml"                   , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args      = task.ext.args  ?: ''
    def args_list = args.tokenize()
    // Sorts output file by chromosome and position using additional options for performance and consistency
    // See https://www.biostars.org/p/66927/ for further details


    def prefix = task.ext.prefix ?: "${meta.id}"

        """
        bedtools \\
            genomecov \\
            -ibam $bam \\
            $args \\
            > ${prefix}.dual.hap.bedgraph

     grep -w 0\$ "${prefix}.dual.hap.bedgraph" | sed 's/0\$/200/g' > "${prefix}.dual.hap.gaps.bedgraph"

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            bedtools: \$(bedtools --version | sed -e "s/bedtools v//g")
        END_VERSIONS
        """


    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch  ${prefix}.${extension}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bedtools: \$(bedtools --version | sed -e "s/bedtools v//g")
    END_VERSIONS
    """
}
