process TIARA_TIARA {
    tag "$meta.id"
    label 'process_medium'

    // WARN: Version information not provided by tool on CLI. Please update version string below when bumping container versions.
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/tiara:1.0.3' :
        'biocontainers/tiara:1.0.3' }"

    input:
    tuple val(meta), path(fasta)
    val(haplotype)

    output:
    tuple val(meta), path("${prefix}*.{txt,txt.gz}"), emit: classifications
    tuple val(meta), path("${removal}")       , emit: contig_removal
    tuple val(meta), path("log_*.{txt,txt.gz}")     , emit: log
    tuple val(meta), path("*.{fasta,fasta.gz}")     , emit: fasta, optional: true
    path "versions.yml"                             , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    def VERSION = '1.0.3' // WARN: Version information not provided by tool on CLI. Please update this string when bumping container versions.
    tiara_report="${prefix}${haplotype}.txt"
    summary="${prefix}${haplotype}.tiara_filter_summary.txt"
    removal="${prefix}${haplotype}.tiara.contig_removal.txt"
    """
    tiara -i ${fasta} \
        -o ${prefix}${haplotype}.txt \
        --threads ${task.cpus} \
        ${args}

    find . -name "*_${fasta}*" -exec sh -c 'file=`basename {}`; mv "\$file" "\${file%%_*}_${prefix}_${haplotype}.fasta"' \\;

        # header
    printf "Category\\tnum_contigs\\tbp\\n" > "$summary"

    # helper that's safe under -euo pipefail
    count() { grep -w "\$1" "$tiara_report" | wc -l || true; }
    bpsum() { grep -w "\$1" "$tiara_report" | awk -F'len=' '{s += \$2} END {print s+0}' || true; }

    c=\$(count mitochondrion); b=\$(bpsum mitochondrion)
    printf "Mitochondrion\\t%s\\t%s\\n" "\$c" "\$b" >> "$summary"

    c=\$(count plastid); b=\$(bpsum plastid)
    printf "Plastid\\t%s\\t%s\\n" "\$c" "\$b" >> "$summary"

    c=\$(count prokarya); b=\$(bpsum prokarya)
    printf "Prokarya\\t%s\\t%s\\n" "\$c" "\$b" >> "$summary"

    c=\$(count bacteria); b=\$(bpsum bacteria)
    printf "Bacteria\\t%s\\t%s\\n" "\$c" "\$b" >> "$summary"

    c=\$(count archaea); b=\$(bpsum archaea)
    printf "Archaea\\t%s\\t%s\\n" "\$c" "\$b" >> "$summary"

    # contig lists (don't fail if empty)
    : > "$removal"
    grep -w mitochondrion "$tiara_report" | awk '{print \$1}' >> "$removal" || true
    grep -w plastid      "$tiara_report" | awk '{print \$1}' >> "$removal" || true
    grep -w prokarya     "$tiara_report" | awk '{print \$1}' >> "$removal" || true
    grep -w bacteria     "$tiara_report" | awk '{print \$1}' >> "$removal" || true
    grep -w archaea      "$tiara_report" | awk '{print \$1}' >> "$removal" || true

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        tiara: ${VERSION}
    END_VERSIONS
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    def VERSION = '1.0.3' // WARN: Version information not provided by tool on CLI. Please update this string when bumping container versions.
    """
    touch ${prefix}.out.txt
    touch log_${prefix}.out.txt
    touch bacteria_${prefix}.fasta

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        tiara: ${VERSION}
    END_VERSIONS
    """
}
