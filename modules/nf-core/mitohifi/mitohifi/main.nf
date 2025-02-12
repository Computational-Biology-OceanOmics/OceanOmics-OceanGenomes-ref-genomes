process MITOHIFI_MITOHIFI {
    tag "$meta.id"
    label 'process_high'


    // Docker image available at the project github repository
    container 'ghcr.io/marcelauliano/mitohifi:master'

    input:
    tuple val(meta), path(input)
    path ref_fa
    path ref_gb
    val input_mode

    output:
    tuple val(meta), path("*fasta")                          , emit: fasta
    tuple val(meta), path("*contigs_stats.tsv")              , emit: stats
    tuple val(meta), path("*gb")                             , emit: gb, optional: true
    tuple val(meta), path("*contigs_annotations.png")        , emit: contigs_annotations, optional: true
    tuple val(meta), path("*contigs_circularization/*.txt")  , emit: contigs_circularization, optional: true
    tuple val(meta), path("*coverage_mapping")               , emit: coverage_mapping, optional: true
    tuple val(meta), path("*coverage_plot.png")              , emit: coverage_plot, optional: true
    tuple val(meta), path("*final_mitogenome.annotation.png"), emit: final_mitogenome_annotation, optional: true
    tuple val(meta), path("*final_mitogenome_choice/*rotated.fa")  , emit: final_mitogenome_choice, optional: true
    tuple val(meta), path("*final_mitogenome.coverage.png")  , emit: final_mitogenome_coverage, optional: true
    path  "versions.yml"                                     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error "MitoHiFi module does not support Conda. Please use Docker / Singularity instead."
    }

    def args = task.ext.args ?: ''
    if (! ["c", "r"].contains(input_mode)) {
        error "r for reads or c for contigs must be specified"
    }
    """
    mitohifi.py -${input_mode} ${input} \\
        -f ${ref_fa} \\
        -g ${ref_gb} \\
        -t $task.cpus ${args}
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mitohifi: \$( mitohifi.py --version 2>&1 | head -n1 | sed 's/^.*MitoHiFi //; s/ .*\$//' )
    END_VERSIONS
    """

    stub:
    """
    touch final_mitogenome.fasta
    touch final_mitogenome.fasta
    touch contigs_stats.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mitohifi: \$( mitohifi.py --version 2>&1 | head -n1 | sed 's/^.*MitoHiFi //; s/ .*\$//')
    END_VERSIONS
    """
}
