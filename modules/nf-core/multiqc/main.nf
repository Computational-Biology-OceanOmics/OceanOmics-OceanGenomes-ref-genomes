process MULTIQC {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/multiqc:1.21--pyhdfd78af_0' :
        'biocontainers/multiqc:1.21--pyhdfd78af_0' }"

    input:
    tuple val(meta), path(files0), path(files1), path(files2), path(files3), path(files4), path(files5), path(files6), path(files7), path(files8), path(files9), path(files10), path(files11), path(files12), path(files13), path(files14)
    path(multiqc_config)
    path(extra_multiqc_config)
    path(multiqc_logo)
    path(wf_summary)
    path(versions)
    path(method_desc)

    output:
    tuple val(meta), path("*multiqc_report.html"), emit: report
    path "*_data"                                , emit: data
    path "*_plots"                               , optional:true, emit: plots
    path "versions.yml"                          , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def config = multiqc_config ? "--config $multiqc_config" : ''
    def extra_config = extra_multiqc_config ? "--config $extra_multiqc_config" : ''
    def logo = multiqc_logo ? "--cl-config 'custom_logo: ${multiqc_logo}'" : ''
    
    """
    for file in \$(ls */*png); do
        mv \$file \$(echo \$file | sed 's/.png/_mqc.png/g')
    done

    multiqc \\
        --force \\
        $args \\
        $config \\
        $extra_config \\
        $logo \\
        .

    mv multiqc_report.html ${meta.id}_multiqc_report.html

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        multiqc: \$( multiqc --version | sed -e "s/multiqc, version //g" )
    END_VERSIONS
    """

    stub:
    """
    mkdir multiqc_data
    touch multiqc_plots
    touch multiqc_report.html

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        multiqc: \$( multiqc --version | sed -e "s/multiqc, version //g" )
    END_VERSIONS
    """
}
