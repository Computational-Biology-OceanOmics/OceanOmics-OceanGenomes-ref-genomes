process PREPARE_PRECOMPUTED_ASSEMBLY {
    tag "${meta.id}"
    label 'process_low'

    conda "conda-forge::sed=4.7"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:20.04' :
        'nf-core/ubuntu:20.04' }"

    input:
    tuple val(meta), path(primary_assembly)

    output:
    tuple val(meta), path("*.hap1.*.fasta"), emit: hap1_fasta
    path "versions.yml"                    , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def hap1_output = "${prefix}.hap1.0.hifiasm.fasta"
    
    """
    # Handle primary assembly (convert GFA to FASTA if needed)
    if [[ "${primary_assembly}" == *.gfa ]] || [[ "${primary_assembly}" == *.gfa.gz ]]; then
        # Extract sequences from GFA format
        if [[ "${primary_assembly}" == *.gz ]]; then
            gunzip -c ${primary_assembly} | awk '/^S/{print ">"\$2"\\n"\$3}' > ${hap1_output}
        else
            awk '/^S/{print ">"\$2"\\n"\$3}' ${primary_assembly} > ${hap1_output}
        fi
    elif [[ "${primary_assembly}" == *.gz ]]; then
        gunzip -c ${primary_assembly} > ${hap1_output}
    else
        cp ${primary_assembly} ${hap1_output}
    fi
    
    echo "Precomputed assembly prepared: ${hap1_output}"
    echo "Note: Skipping hap2 processes for precomputed single-haplotype assembly"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bash: \$(bash --version | head -n 1 | sed 's/.*version //; s/ .*//')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def hap1_output = "${prefix}.hap1.0.hifiasm.fasta"
    """
    touch ${hap1_output}
    touch versions.yml
    """
}