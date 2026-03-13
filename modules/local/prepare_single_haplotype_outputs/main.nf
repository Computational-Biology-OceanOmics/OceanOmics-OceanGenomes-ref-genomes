process PREPARE_SINGLE_HAPLOTYPE_OUTPUTS {
    tag "${meta.id}"
    label 'process_low'

    conda "conda-forge::sed=4.7"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:20.04' :
        'nf-core/ubuntu:20.04' }"

    input:
    tuple val(meta), path(hap1_scaffold), path(hap2_scaffold), val(combined_name)

    output:
    tuple val(meta), path("*_combined_scaffolds.fa"), emit: combined_file
    tuple val(meta), path("*.hap1.scaffolds_1.fa")   , emit: hap1_file
    tuple val(meta), path("*.hap2.scaffolds_2.fa")   , emit: hap2_file
    path  "versions.yml"                              , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    # For single-haplotype precomputed assemblies, we simply create symbolic links
    # The hap1 scaffold is the actual assembly, and we create a link for hap2
    # to maintain compatibility with downstream processes
    
    echo "Processing single-haplotype precomputed assembly: ${meta.id}"
    echo "Note: This is a single-haplotype assembly; hap2 files are symbolic links to hap1"
    
    # Create the combined file (just hap1)
    ln -s ${hap1_scaffold} ${combined_name}
    
    # Create hap1 output (symlink to original)
    ln -s ${hap1_scaffold} ${prefix}.hap1.scaffolds_1.fa
    
    # Create hap2 output (symlink to hap1 for compatibility)
    ln -s ${hap1_scaffold} ${prefix}.hap2.scaffolds_2.fa
    
    # Count scaffolds
    scaffold_count=\$(grep -c '^>' ${hap1_scaffold} || echo 0)
    
    echo "Single-haplotype assembly prepared:"
    echo "  Scaffold count: \${scaffold_count}"
    echo "  Combined file: ${combined_name}"
    echo "  Note: hap2 files are symbolic links to hap1"

    cat <<-END_VERSIONS > versions.yml
\t"${task.process}":
\t    bash: \$(bash --version | head -n 1 | sed 's/.*version //; s/ .*//')
\tEND_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${combined_name}
    touch ${prefix}.hap1.scaffolds_1.fa
    touch ${prefix}.hap2.scaffolds_2.fa
    touch versions.yml
    """
}
