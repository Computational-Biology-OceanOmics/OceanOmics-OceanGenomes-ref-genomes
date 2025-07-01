include { YAHS_SUBWORKFLOW } from '../yahs/main'
include { SALSA_SUBWORKFLOW } from '../salsa/main'

workflow SCAFFOLDING {
    take:
    ch_yahs_hap1_in         // channel for YAHS HAP1 input [meta, bam, fasta, fai]
    ch_yahs_hap2_in         // channel for YAHS HAP2 input [meta, bam, fasta, fai]
    ch_bamtobed_hap1_in     // channel for SALSA HAP1 BAM input [meta, bam]
    ch_bamtobed_hap2_in     // channel for SALSA HAP2 BAM input [meta, bam]
    ch_fasta_index_hap1     // channel for SALSA HAP1 fasta/index [meta, fasta, fai]
    ch_fasta_index_hap2     // channel for SALSA HAP2 fasta/index [meta, fasta, fai]
    ch_hap1_contigs         // channel for SALSA HAP1 GFA [meta, gfa]
    ch_hap2_contigs         // channel for SALSA HAP2 GFA [meta, gfa]
    scaffolder_type         // string: 'yahs' or 'salsa'
    
    main:
    ch_versions = Channel.empty()
    
    // Initialize empty output channels
    hap1_scaffolds = Channel.empty()
    hap2_scaffolds = Channel.empty()
    
    if (scaffolder_type == 'yahs') {
        YAHS_SUBWORKFLOW (
            ch_yahs_hap1_in,
            ch_yahs_hap2_in
        )
        hap1_scaffolds = YAHS_SUBWORKFLOW.out.hap1_scaffolds
        hap2_scaffolds = YAHS_SUBWORKFLOW.out.hap2_scaffolds
        ch_versions = ch_versions.mix(YAHS_SUBWORKFLOW.out.versions)
        
    } else if (scaffolder_type == 'salsa') {
        SALSA_SUBWORKFLOW (
            ch_bamtobed_hap1_in,
            ch_bamtobed_hap2_in,
            ch_fasta_index_hap1,
            ch_fasta_index_hap2,
            ch_hap1_contigs,
            ch_hap2_contigs
        )
        hap1_scaffolds = SALSA_SUBWORKFLOW.out.hap1_scaffolds
        hap2_scaffolds = SALSA_SUBWORKFLOW.out.hap2_scaffolds
        ch_versions = ch_versions.mix(SALSA_SUBWORKFLOW.out.versions)
    }
    
    emit:
    hap1_scaffolds = hap1_scaffolds
    hap2_scaffolds = hap2_scaffolds
    versions = ch_versions
}