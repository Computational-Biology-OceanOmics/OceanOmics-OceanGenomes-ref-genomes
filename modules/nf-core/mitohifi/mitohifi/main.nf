process MITOHIFI_MITOHIFI {
    tag "$meta.id"
    label 'process_high'

    container 'ghcr.io/marcelauliano/mitohifi:master'

    input:
    tuple val(meta), path(input)
    tuple val(sample), val(date)
    path ref_fa
    path ref_gb
    val input_mode
    val tech
    val version

    output:
    tuple val(meta), path("${sample}.${tech}.${date}.${version}*.fasta"), emit: fasta
    tuple val(meta), path("${sample}.${tech}.${date}.${version}*contigs_stats.tsv"), emit: stats
    tuple val(meta), path("${sample}.${tech}.${date}.${version}*.gb"), emit: gb, optional: true
    tuple val(meta), path("${sample}.${tech}.${date}.${version}*contigs_annotations.png"), emit: contigs_annotations, optional: true
    tuple val(meta), path("${sample}.${tech}.${date}.${version}*contigs_circularization/*.txt"), emit: contigs_circularization, optional: true
    tuple val(meta), path("${sample}.${tech}.${date}.${version}*coverage_mapping"), emit: coverage_mapping, optional: true
    tuple val(meta), path("${sample}.${tech}.${date}.${version}*coverage_plot.png"), emit: coverage_plot, optional: true
    tuple val(meta), path("${sample}.${tech}.${date}.${version}*final_mitogenome.annotation.png"), emit: final_mitogenome_annotation, optional: true
    tuple val(meta), path("${sample}.${tech}.${date}.${version}*final_mitogenome_choice/*rotated.fa"), emit: final_mitogenome_choice, optional: true
    tuple val(meta), path("${sample}.${tech}.${date}.${version}*final_mitogenome.coverage.png"), emit: final_mitogenome_coverage, optional: true
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
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
        -t $task.cpus ${args} \\
        -o ${sample}.${tech}.${date}.${version}
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mitohifi: \$( mitohifi.py --version 2>&1 | head -n1 | sed 's/^.*MitoHiFi //; s/ .*\$//' )
    END_VERSIONS
    """

    stub:
    """
    touch ${sample}.${tech}.${date}.${version}_final_mitogenome.fasta
    touch ${sample}.${tech}.${date}.${version}_contigs_stats.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mitohifi: \$( mitohifi.py --version 2>&1 | head -n1 | sed 's/^.*MitoHiFi //; s/ .*\$//')
    END_VERSIONS
    """
}