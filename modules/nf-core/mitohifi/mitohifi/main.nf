process MITOHIFI_MITOHIFI {
    tag "$meta.id"
    label 'process_high'
    errorStrategy { task.attempt <= 2 ? 'retry' : 'ignore' }
    maxRetries 2

    container 'ghcr.io/marcelauliano/mitohifi:master'

    input:
    tuple val(meta), path(hifi_cat)
    tuple val(sample), val(date)
    path ref_fa
    path ref_gb
    val input_mode
    val tech
    val version

    output:
    tuple val(meta), path("${sample}.${tech}.${date}.${version}*.fasta"), emit: fasta, optional: true
    tuple val(meta), path("${sample}.${tech}.${date}.${version}*contigs_stats.tsv"), emit: stats, optional: true
    tuple val(meta), path("${sample}.${tech}.${date}.${version}*.gb"), emit: gb, optional: true
    tuple val(meta), path("${sample}.${tech}.${date}.${version}*contigs_annotations.png"), emit: contigs_annotations, optional: true
    tuple val(meta), path("${sample}.${tech}.${date}.${version}*contigs_circularization/*.txt"), emit: contigs_circularization, optional: true
    tuple val(meta), path("${sample}.${tech}.${date}.${version}*coverage_mapping"), emit: coverage_mapping, optional: true
    tuple val(meta), path("${sample}.${tech}.${date}.${version}*coverage_plot.png"), emit: coverage_plot, optional: true
    tuple val(meta), path("${sample}.${tech}.${date}.${version}*final_mitogenome.annotation.png"), emit: final_mitogenome_annotation, optional: true
    tuple val(meta), path("${sample}.${tech}.${date}.${version}*final_mitogenome_choice/*rotated.fa"), emit: final_mitogenome_choice, optional: true
    tuple val(meta), path("${sample}.${tech}.${date}.${version}*final_mitogenome.coverage.png"), emit: final_mitogenome_coverage, optional: true
    tuple val(meta), path("${sample}.${tech}.${date}.${version}*p.ctg.gfa"), emit: p_ctg_gfa, optional: true
    tuple val(meta), path("${sample}.${tech}.${date}.${version}*p_ctg.fa"), emit: p_ctg_fa, optional: true
    tuple val(meta), path("${sample}.${tech}.${date}.${version}*a_ctg.fa"), emit: a_ctg_fa, optional: true
    tuple val(meta), path("${sample}.${tech}.${date}.${version}*a_ctg.gfa"), emit: a_ctg_gfa, optional: true
    tuple val(meta), path("${sample}.${tech}.${date}.${version}*.hifiasm.log"), emit: hifiasm_log, optional: true
    tuple val(meta), path("${sample}.${tech}.${date}.${version}*.hifiasm.contigs.fasta"), emit: hifiasm_contigs, optional: true
    path "versions.yml", emit: versions
    path "*_failed.txt", emit: failed_samples, optional: true

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    if (! ["c", "r"].contains(input_mode)) {
        error "r for reads or c for contigs must be specified"
    }
    """
    set +e  # Don't exit on error

    # Run MitoHiFi
    mitohifi.py -${input_mode} ${hifi_cat} \\
        -f ${ref_fa} \\
        -g ${ref_gb} \\
        -t $task.cpus ${args} \\
        -o ${sample}.${tech}.${date}.${version}

    exit_code=\$?

    # Check if the main output was created and rename it
    if [ -f "${sample}.${tech}.${date}.${version}.fasta" ]; then
        sed -i "/^>/s/.*/>${sample}.${tech}.${date}.${version}/g" ${sample}.${tech}.${date}.${version}.fasta
    fi

    # Handle intermediate files - copy them with consistent naming regardless of success/failure
    # Primary assembly file (this is what you specifically want)
    for file in *p_ctg.fa; do
        if [ -f "\$file" ]; then
            cp "\$file" "${sample}.${tech}.${date}.${version}.\$file"
        fi
    done

    # Primary assembly GFA file
    for file in *p_ctg.gfa; do
        if [ -f "\$file" ]; then
            cp "\$file" "${sample}.${tech}.${date}.${version}.\$file"
        fi
    done

    # Other intermediate files you might want to capture
    for file in *a_ctg.fa; do
        if [ -f "\$file" ]; then
            cp "\$file" "${sample}.${tech}.${date}.${version}.\$file"
        fi
    done

    for file in *a_ctg.gfa; do
        if [ -f "\$file" ]; then
            cp "\$file" "${sample}.${tech}.${date}.${version}.\$file"
        fi
    done

    # Capture hifiasm log if it exists
    if [ -f "hifiasm.log" ]; then
        cp "hifiasm.log" "${sample}.${tech}.${date}.${version}.hifiasm.log"
    fi

    # Capture contigs fasta if it exists
    if [ -f "hifiasm.contigs.fasta" ]; then
        cp "hifiasm.contigs.fasta" "${sample}.${tech}.${date}.${version}.hifiasm.contigs.fasta"
    fi

    # Create failure indicator if the process failed
    if [ \$exit_code -ne 0 ]; then
        echo "${meta.id}" > ${meta.id}_failed.txt
        echo "MitoHiFi failed for sample ${meta.id} with exit code \$exit_code" >&2
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mitohifi: \$( mitohifi.py --version 2>&1 | head -n1 | sed 's/^.*MitoHiFi //; s/ .*\$//' )
    END_VERSIONS
    """

    stub:
    """
    # Create all expected output files for testing
    touch ${sample}.${tech}.${date}.${version}_final_mitogenome.fasta
    touch ${sample}.${tech}.${date}.${version}_contigs_stats.tsv
    touch ${sample}.${tech}.${date}.${version}_final_mitogenome.gb
    touch ${sample}.${tech}.${date}.${version}_contigs_annotations.png
    touch ${sample}.${tech}.${date}.${version}_coverage_plot.png
    touch ${sample}.${tech}.${date}.${version}_final_mitogenome.annotation.png
    touch ${sample}.${tech}.${date}.${version}_final_mitogenome.coverage.png
    touch ${sample}.${tech}.${date}.${version}.gbk.HiFiMapped.bam.filtered.assembled.p_ctg.gfa
    touch ${sample}.${tech}.${date}.${version}.gbk.HiFiMapped.bam.filtered.assembled.p_ctg.fa
    touch ${sample}.${tech}.${date}.${version}.gbk.HiFiMapped.bam.filtered.assembled.a_ctg.fa
    touch ${sample}.${tech}.${date}.${version}.gbk.HiFiMapped.bam.filtered.assembled.a_ctg.gfa
    touch ${sample}.${tech}.${date}.${version}.hifiasm.log
    touch ${sample}.${tech}.${date}.${version}.hifiasm.contigs.fasta

    # Create directory structures that might be expected
    mkdir -p ${sample}.${tech}.${date}.${version}_contigs_circularization
    touch ${sample}.${tech}.${date}.${version}_contigs_circularization/test.txt
    mkdir -p ${sample}.${tech}.${date}.${version}_coverage_mapping
    mkdir -p ${sample}.${tech}.${date}.${version}_final_mitogenome_choice
    touch ${sample}.${tech}.${date}.${version}_final_mitogenome_choice/rotated.fa

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mitohifi: \$( mitohifi.py --version 2>&1 | head -n1 | sed 's/^.*MitoHiFi //; s/ .*\$//')
    END_VERSIONS
    """
}