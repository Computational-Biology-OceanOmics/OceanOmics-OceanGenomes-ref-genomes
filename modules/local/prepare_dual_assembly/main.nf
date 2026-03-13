process PREPARE_DUAL_ASSEMBLY {
    tag "${meta.id}"
    label 'process_low'

    conda "conda-forge::sed=4.7"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:20.04' :
        'nf-core/ubuntu:20.04' }"

    input:
    tuple val(meta), path(hap1_assembly), path(hap2_assembly)

    output:
    tuple val(meta), path("*.hap1.0.hifiasm.fasta"), emit: hap1_fasta
    tuple val(meta), path("*.hap2.0.hifiasm.fasta"), emit: hap2_fasta
    path "versions.yml"                            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix   = task.ext.prefix ?: "${meta.id}"
    def hap1_out = "${prefix}.hap1.0.hifiasm.fasta"
    def hap2_out = "${prefix}.hap2.0.hifiasm.fasta"
    """
    normalise_fasta() {
        local src="\$1"
        local dst="\$2"
        if [[ "\$src" == *.gfa.gz ]]; then
            gunzip -c "\$src" | awk '/^S/{print ">"\$2"\\n"\$3}' > "\$dst"
        elif [[ "\$src" == *.gfa ]]; then
            awk '/^S/{print ">"\$2"\\n"\$3}' "\$src" > "\$dst"
        elif [[ "\$src" == *.gz ]]; then
            gunzip -c "\$src" > "\$dst"
        else
            cp "\$src" "\$dst"
        fi
    }

    normalise_fasta "${hap1_assembly}" "${hap1_out}"
    normalise_fasta "${hap2_assembly}" "${hap2_out}"

    echo "Hap1 scaffolds: \$(grep -c '^>' ${hap1_out} || echo 0)"
    echo "Hap2 scaffolds: \$(grep -c '^>' ${hap2_out} || echo 0)"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bash: \$(bash --version | head -n 1 | sed 's/.*version //; s/ .*//')
    END_VERSIONS
    """

    stub:
    def prefix   = task.ext.prefix ?: "${meta.id}"
    def hap1_out = "${prefix}.hap1.0.hifiasm.fasta"
    def hap2_out = "${prefix}.hap2.0.hifiasm.fasta"
    """
    touch ${hap1_out}
    touch ${hap2_out}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bash: \$(bash --version | head -n 1 | sed 's/.*version //; s/ .*//')
    END_VERSIONS
    """
}
