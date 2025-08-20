include { BAMTOBED as BAMTOBED_HAP1                      } from '../../../modules/nf-core/bedtools/bamtobed/main'
include { BAMTOBED as BAMTOBED_HAP2                      } from '../../../modules/nf-core/bedtools/bamtobed/main'
include { SALSA2 as SALSA2_HAP1                          } from '../../../modules/nf-core/salsa2/main'
include { SALSA2 as SALSA2_HAP2                          } from '../../../modules/nf-core/salsa2/main'


workflow SALSA {

        take: 
        ch_bamtobed_hap1_in         //  channel [val(meta), path(bam) ] for hap2
        ch_bamtobed_hap2_in         //  channel [val(meta), path(bam) ] for hap2
        ch_fasta_index_hap1         //  channel [val(meta), path(fasta), path(fai) ] for hap1
        ch_fasta_index_hap2         //  channel [val(meta), path(fasta), path(fai) ] for hap2
        ch_hap1_contigs    // Add HIFIASM contigs for SALSA
        ch_hap2_contigs    // Add HIFIASM contigs for SALSA

        main:
        ch_versions = Channel.empty()


    //RUN SALSA2
    // MODULE: Run bamtobed
    //

    BAMTOBED_HAP1(ch_bamtobed_hap1_in)
    BAMTOBED_HAP2(ch_bamtobed_hap2_in)
    ch_versions = ch_versions.mix(BAMTOBED_HAP1.out.versions.first())
    ch_versions = ch_versions.mix(BAMTOBED_HAP2.out.versions.first())

    // Join all inputs by meta.id for synchronized processing
    ch_salsa2_hap1_joined = ch_fasta_index_hap1
        .join(BAMTOBED_HAP1.out.bed, by: 0)
        .join(ch_hap1_contigs, by: 0)

    ch_salsa2_hap2_joined = ch_fasta_index_hap2
        .join(BAMTOBED_HAP2.out.bed, by: 0)
        .join(ch_hap2_contigs, by: 0)

    // Run SALSA2 with synchronized inputs
    SALSA2_HAP1(
        ch_salsa2_hap1_joined.map { meta, fasta, fai, bed, gfa -> [meta, fasta, fai] },
        ch_salsa2_hap1_joined.map { meta, fasta, fai, bed, gfa -> [meta, bed] },
        ch_salsa2_hap1_joined.map { meta, fasta, fai, bed, gfa -> [meta, gfa] },
        [],  // dup  
        [],  // filter_bed
        ".1.salsa.hap1"
    )

    SALSA2_HAP2(
        ch_salsa2_hap2_joined.map { meta, fasta, fai, bed, gfa -> [meta, fasta, fai] },
        ch_salsa2_hap2_joined.map { meta, fasta, fai, bed, gfa -> [meta, bed] },
        ch_salsa2_hap2_joined.map { meta, fasta, fai, bed, gfa -> [meta, gfa] },
        [],  // dup
        [],  // filter_bed
        ".1.salsa.hap2"
    )

    ch_versions = ch_versions.mix(SALSA2_HAP1.out.versions.first())
    ch_versions = ch_versions.mix(SALSA2_HAP2.out.versions.first())

    emit:
    hap1_scaffolds = SALSA2_HAP1.out.salsa_fasta
    hap2_scaffolds = SALSA2_HAP2.out.salsa_fasta
    versions = ch_versions

    }