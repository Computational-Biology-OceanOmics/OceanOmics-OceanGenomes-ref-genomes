include { YAHS as YAHS_HAP1                              } from '../../../modules/nf-core/yahs/main'
include { YAHS as YAHS_HAP2                              } from '../../../modules/nf-core/yahs/main'

workflow YAHS {

    take:

    ch_yahs_decontam_hap1_in    //channel [val(meta), [bam], [fasta], [fai]] for hap1
    ch_yahs_decontam_hap2_in    //channel [val(meta), [bam], [fasta], [fai]] for hap2

    main:
    ch_versions = Channel.empty()

    //
    // MODULE: Run Yahs
    //

    YAHS_HAP1 (
        ch_yahs_hap1_in,
        ".1.yahs.hap1"
    )
    ch_versions = ch_versions.mix(YAHS_HAP1.out.versions.first())

    YAHS_HAP2 (
        ch_yahs_hap2_in,
        ".1.yahs.hap2"
    )
    ch_versions = ch_versions.mix(YAHS_HAP2.out.versions.first())


emit:
// These are the key outputs used in your main workflow
hap1_scaffolds = YAHS_HAP1.out.scaffolds_fasta  // Used in FCSGX
hap2_scaffolds = YAHS_HAP2.out.scaffolds_fasta  // Used in FCSGX

// Always include versions
versions = ch_versions
}