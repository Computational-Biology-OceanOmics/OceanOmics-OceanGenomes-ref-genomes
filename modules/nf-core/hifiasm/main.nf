process HIFIASM {
    tag "$meta.id"
    label "process_high"

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
<<<<<<< HEAD
        'https://depot.galaxyproject.org/singularity/hifiasm:0.19.8--h43eeafb_0' :
=======
        'docker://quay.io/biocontainers/hifiasm:0.25.0--h5ca1c30_0' :
>>>>>>> dd2184d (updated scripts and containers and added mitohifi)
        'biocontainers/hifiasm:0.19.8--h43eeafb_0' }"

    input:
    tuple val(meta), path(reads), path(hic_read1), path(hic_read2)
    val asmversion
    path  paternal_kmer_dump
    path  maternal_kmer_dump

    output:
    tuple val(meta), path("*.r_utg.gfa")       , emit: raw_unitigs
    tuple val(meta), path("*.ec.bin")          , emit: corrected_reads
    tuple val(meta), path("*.ovlp.source.bin") , emit: source_overlaps
    tuple val(meta), path("*.ovlp.reverse.bin"), emit: reverse_overlaps
    tuple val(meta), path("*.bp.p_ctg.gfa")    , emit: processed_contigs, optional: true
    tuple val(meta), path("*.p_utg.gfa")       , emit: processed_unitigs, optional: true
    tuple val(meta), path("*.p_ctg.gfa")       , emit: primary_contigs  , optional: true
    tuple val(meta), path("*.a_ctg.gfa")       , emit: alternate_contigs, optional: true
    tuple val(meta), path("*.hap1.p_ctg.gfa")  , emit: hap1_contigs     , optional: true
    tuple val(meta), path("*.hap2.p_ctg.gfa")  , emit: hap2_contigs     , optional: true
    tuple val(meta), path("*.log")             , emit: log
    path  "versions.yml"                       , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    if ((paternal_kmer_dump) && (maternal_kmer_dump) && (hic_read1) && (hic_read2)) {
        error "Hifiasm Trio-binning and Hi-C integrated should not be used at the same time"
    } else if ((paternal_kmer_dump) && !(maternal_kmer_dump)) {
        error "Hifiasm Trio-binning requires maternal data"
    } else if (!(paternal_kmer_dump) && (maternal_kmer_dump)) {
        error "Hifiasm Trio-binning requires paternal data"
    } else if ((paternal_kmer_dump) && (maternal_kmer_dump)) {
        """
        hifiasm \\
            $args \\
            -o ${prefix} \\
            -t $task.cpus \\
            -1 $paternal_kmer_dump \\
            -2 $maternal_kmer_dump \\
            $reads \\
            2> >( tee ${prefix}.stderr.log >&2 )


        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            hifiasm: \$(hifiasm --version 2>&1)
        END_VERSIONS
        """
    } else if ((hic_read1) && !(hic_read2)) {
        error "Hifiasm Hi-C integrated requires paired-end data (only R1 specified here)"
    } else if (!(hic_read1) && (hic_read2)) {
        error "Hifiasm Hi-C integrated requires paired-end data (only R2 specified here)"
    } else if ((hic_read1) && (hic_read2)) {
        """
        hifiasm \\
            $args \\
            -o ${prefix} \\
            -t $task.cpus \\
            --h1 $hic_read1 \\
            --h2 $hic_read2 \\
            $reads \\
            2> >( tee ${prefix}.stderr.log >&2 )


        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            hifiasm: \$(hifiasm --version 2>&1)
        END_VERSIONS
        """
    } else { // Phasing with Hi-C data is not supported yet
        """
        hifiasm \\
            $args \\
            -o ${prefix} \\
            -t $task.cpus \\
            $reads \\
            2> >( tee ${prefix}.stderr.log >&2 )

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            hifiasm: \$(hifiasm --version 2>&1)
        END_VERSIONS
        """
    }
        stub:
        def args = task.ext.args ?: ''
        def prefix = task.ext.prefix ?: "${meta.id}"
        """
        touch ${prefix}.r_utg.gfa
        touch ${prefix}.ec.bin
        touch ${prefix}.ovlp.source.bin
        touch ${prefix}.ovlp.reverse.bin
        touch ${prefix}.bp.p_ctg.gfa
        touch ${prefix}.p_utg.gfa
        touch ${prefix}.p_ctg.gfa
        touch ${prefix}.a_ctg.gfa
        touch ${prefix}.hap1.p_ctg.gfa
        touch ${prefix}.hap2.p_ctg.gfa
        touch ${prefix}.stderr.log

        cat <<-END_VERSIONS > versions.yml
        "${task.process}":
            hifiasm: \$(hifiasm --version 2>&1)
        END_VERSIONS
        """

}
