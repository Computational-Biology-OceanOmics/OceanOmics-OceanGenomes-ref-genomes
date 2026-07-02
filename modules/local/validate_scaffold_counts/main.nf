process VALIDATE_SCAFFOLD_COUNTS {
    tag "$meta.id"
    label 'process_single'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/fastqc:0.12.1--hdfd78af_0' :
        'biocontainers/fastqc:0.12.1--hdfd78af_0' }"

    input:
    tuple val(meta), path(count_report), path(hap1_summary), path(hap2_summary)

    output:
    tuple val(meta), path("scaffold_validation.txt"), emit: report
    path  "versions.yml"                            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    hap1_gf=\$(grep "# scaffolds" "${hap1_summary}" | head -1 | awk '{print \$NF}')
    hap2_gf=\$(grep "# scaffolds" "${hap2_summary}" | head -1 | awk '{print \$NF}')

    hap1_cat=\$(grep "Haplotype 1 - Renamed" "${count_report}" | grep -o '[0-9]*\$')
    hap2_cat=\$(grep "Haplotype 2 - Renamed" "${count_report}" | grep -o '[0-9]*\$')

    if [ "\$hap1_gf" != "\$hap1_cat" ] || [ "\$hap2_gf" != "\$hap2_cat" ]; then
        echo "ERROR: Scaffold count mismatch for ${meta.id}!" >&2
        echo "  gfastats        Hap1: \$hap1_gf  Hap2: \$hap2_gf" >&2
        echo "  scaffold_counts Hap1: \$hap1_cat  Hap2: \$hap2_cat" >&2
        echo "Cause: Nextflow resume cache inconsistency — BBMAP re-ran but CAT_SCAFFOLDS was cached." >&2
        echo "Fix: re-run this sample without -resume." >&2
        exit 1
    fi

    {
        echo "PASSED: ${meta.id}"
        echo "  gfastats        Hap1: \$hap1_gf  Hap2: \$hap2_gf"
        echo "  scaffold_counts Hap1: \$hap1_cat  Hap2: \$hap2_cat"
    } > scaffold_validation.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bash: \$(bash --version | head -n1 | cut -d' ' -f4)
    END_VERSIONS
    """
}
