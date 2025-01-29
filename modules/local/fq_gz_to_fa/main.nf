process FQ_GZ_TO_FA {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/fastqc:0.12.1--hdfd78af_0' :
        'biocontainers/fastqc:0.12.1--hdfd78af_0' }"

    input:
    tuple val(meta), path(fqs)

    output:
    tuple val(meta), path("*fa"), emit: fa

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    fqs=( $fqs )
    for fq in \${fqs[*]}
    do
        fa=\$(echo \$fq | sed 's/fq.gz/fa/g' | sed 's/fastq.gz/fa/g')
        zcat \$fq | awk '{if(NR%4==1) {printf(">%s\\n",substr(\$0,2));} else if(NR%4==2) print;}' > \$fa
    done
    """
}
