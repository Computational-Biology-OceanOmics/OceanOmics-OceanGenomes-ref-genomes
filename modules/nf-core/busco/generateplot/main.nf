process BUSCO_GENERATEPLOT {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
<<<<<<< HEAD
    container 'docker://ezlabgva/busco:v5.7.1_cv1'
=======
    container 'docker://quay.io/biocontainers/busco:5.8.3--pyhdfd78af_0'
>>>>>>> dd2184d (updated scripts and containers and added mitohifi)

    input:
    tuple val(meta), path(short_summary_txt, stageAs: 'busco/*')
    val(asmversion)

    output:
    tuple val(meta), path('*.png'), emit: png
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args    = task.ext.args     ?: ''
    def prefix  = task.ext.prefix   ?: 'busco_figure'
    """
    generate_plot.py \\
        $args \\
        -wd busco

    mv ./busco/busco_figure.png ${meta.id}_${asmversion}_${prefix}.png

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        busco: \$( busco --version 2>&1 | sed 's/^BUSCO //' )
    END_VERSIONS
    """

    stub:
    def prefix  = task.ext.prefix   ?: 'busco_figure'
    """
    touch ${prefix}.png

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        busco: \$( busco --version 2>&1 | sed 's/^BUSCO //' )
    END_VERSIONS
    """
}
