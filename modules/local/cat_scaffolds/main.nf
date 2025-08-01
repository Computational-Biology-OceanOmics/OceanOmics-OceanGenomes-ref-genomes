process CAT_SCAFFOLDS {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/fastqc:0.12.1--hdfd78af_0' :
        'biocontainers/fastqc:0.12.1--hdfd78af_0' }"

    input:
    tuple val(meta), path(scaffolds)
    val asmversion

    output:
    tuple val(meta), path("*_combined_scaffolds.fa"), emit: cat_file
    tuple val(meta), path("*hap1.scaffolds_1.fa")     , emit: hap1_scaffold
    tuple val(meta), path("*hap2.scaffolds_2.fa")     , emit: hap2_scaffold
    path  "scaffold_counts.txt"                       , emit: count_report
    path  "versions.yml"                           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}" 
    """

    # Count scaffolds before renaming
    hap1_original=\$(grep -c '^>' ${prefix}.2.tiara.hap1_scaffolds.fa)
    hap2_original=\$(grep -c '^>' ${prefix}.2.tiara.hap2_scaffolds.fa)
    
    # Rename scaffolds
    awk '/^>/ { sub(/^>scaffold/, ">H1.scaffold"); print; next } { print }' ${prefix}.2.tiara.hap1_scaffolds.fa > ${prefix}.hap1.scaffolds_1.fa
    awk '/^>/ { sub(/^>scaffold/, ">H2.scaffold"); print; next } { print }' ${prefix}.2.tiara.hap2_scaffolds.fa > ${prefix}.hap2.scaffolds_2.fa

    # Count scaffolds after renaming (should match original, but for verification)
    hap1_renamed=\$(grep -c '^>' ${prefix}.hap1.scaffolds_1.fa)
    hap2_renamed=\$(grep -c '^>' ${prefix}.hap2.scaffolds_2.fa)


    # Concatenate hap1 and hap2 scaffolds
    cat ${prefix}.hap1.scaffolds_1.fa ${prefix}.hap2.scaffolds_2.fa > "${prefix}${asmversion}_combined_scaffolds.fa"

    # Count scaffolds in cat 
    cat_fa=\$(grep -c '^>' ${prefix}${asmversion}_combined_scaffolds.fa)

    # Write count report
    cat <<-END_COUNTS > scaffold_counts.txt
    Haplotype 1 - Original: \$hap1_original
    Haplotype 1 - Renamed : \$hap1_renamed
    Haplotype 2 - Original: \$hap2_original
    Haplotype 2 - Renamed : \$hap2_renamed
    Cat Scaff : \$cat_fa
    END_COUNTS
    
    # Capture FastQC version in versions.yml
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fastqc: \$(fastqc --version | sed '/FastQC v/!d; s/.*v//')
    END_VERSIONS
    """
}
