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
    
    //RUN SALSA2
    // MODULE: Run bamtobed
    //

    ch_bamtobed_hap1_in = OMNIC_HAP1.out.omnic_bam
    ch_bamtobed_hap2_in = OMNIC_HAP2.out.omnic_bam

    BAMTOBED_HAP1(
        ch_bamtobed_hap1_in
    )
    ch_versions = ch_versions.mix(BAMTOBED_HAP1.out.versions.first())

    BAMTOBED_HAP2(
        ch_bamtobed_hap2_in
    )
    ch_versions = ch_versions.mix(BAMTOBED_HAP2.out.versions.first())

    //MODULE : Run SALSA2

    ch_fasta_index_hap1 = GFASTATS_HAP1.out.assembly.join(OMNIC_HAP1.out.omnic_fai)
    ch_fasta_index_hap2 = GFASTATS_HAP2.out.assembly.join(OMNIC_HAP2.out.omnic_fai)

    SALSA2_HAP1 (
        ch_fasta_index_hap1,
        BAMTOBED_HAP1.out.bed,
        HIFIASM.out.hap1_contigs,  // gfa
        [],  // dup  
        [],  // filter_bed
        ".1.salsa.hap1" //haplotype file naming
    )
    ch_versions = ch_versions.mix(SALSA2_HAP1.out.versions.first())

    SALSA2_HAP2 (
        ch_fasta_index_hap2,
        BAMTOBED_HAP2.out.bed,
        HIFIASM.out.hap2_contigs,  // gfa
        [],  // dup
        [],  // filter_bed
        ".1.salsa.hap2" //haplotype file naming
    )
    ch_versions = ch_versions.mix(SALSA2_HAP2.out.versions.first())

    emit:
    hap1_scaffolds = SALSA2_HAP1.out.fasta  // Adjust based on actual SALSA2 output
    hap2_scaffolds = SALSA2_HAP2.out.fasta  // Adjust based on actual SALSA2 output
    versions = ch_versions

    }