include { FCS_FCSGX as FCS_FCSGX_HAP1                    } from '../../../modules/nf-core/fcs/fcsgx/main'
include { FCS_FCSGX as FCS_FCSGX_HAP2                    } from '../../../modules/nf-core/fcs/fcsgx/main'
include { FCSGX_CLEANGENOME as FCSGX_CLEANGENOME_HAP1    } from '../../../modules/nf-core/fcsgx/cleangenome/main'
include { FCSGX_CLEANGENOME as FCSGX_CLEANGENOME_HAP2    } from '../../../modules/nf-core/fcsgx/cleangenome/main'
include { TIARA_TIARA as TIARA_TIARA_HAP1                } from '../../../modules/nf-core/tiara/tiara/main'
include { TIARA_TIARA as TIARA_TIARA_HAP2                } from '../../../modules/nf-core/tiara/tiara/main'
include { BBMAP_FILTERBYNAME as BBMAP_FILTERBYNAME_HAP1  } from '../../../modules/local/bbmap/filterbyname/main'
include { BBMAP_FILTERBYNAME as BBMAP_FILTERBYNAME_HAP2  } from '../../../modules/local/bbmap/filterbyname/main'

workflow DECONTAMINATION {
    take:
    ch_hap1_scaffolds    // channel [val(meta), path(scaffolds)] for hap1
    ch_hap2_scaffolds    // channel [val(meta), path(scaffolds)] for hap2
    gxdb                 // path to GX database
    scaffolder_suffix    // string like '.1.yahs' or '.1.salsa'

    main:
    ch_versions = Channel.empty()

    //
    // MODULE: Run FCS_FCSGX
    //
    FCS_FCSGX_HAP1 (
        ch_hap1_scaffolds,
        gxdb,
        "${scaffolder_suffix}.hap1.NCBI"
    )
    ch_versions = ch_versions.mix(FCS_FCSGX_HAP1.out.versions.first())

    FCS_FCSGX_HAP2 (
        ch_hap2_scaffolds,
        gxdb,
        "${scaffolder_suffix}.hap2.NCBI"
    )
    ch_versions = ch_versions.mix(FCS_FCSGX_HAP2.out.versions.first())

    //
    // MODULE: Run FCSGX_CLEANGENOME
    //
    FCSGX_CLEANGENOME_HAP1 (
        ch_hap1_scaffolds.join(FCS_FCSGX_HAP1.out.fcs_gx_report)
    )
    ch_versions = ch_versions.mix(FCSGX_CLEANGENOME_HAP1.out.versions.first())

    FCSGX_CLEANGENOME_HAP2 (
        ch_hap2_scaffolds.join(FCS_FCSGX_HAP2.out.fcs_gx_report)
    )
    ch_versions = ch_versions.mix(FCSGX_CLEANGENOME_HAP2.out.versions.first())

    //
    // MODULE: Run Tiara
    //
    TIARA_TIARA_HAP1 (
        FCSGX_CLEANGENOME_HAP1.out.cleaned,
        "${scaffolder_suffix}.hap1.tiara"
    )
    ch_versions = ch_versions.mix(TIARA_TIARA_HAP1.out.versions.first())

    TIARA_TIARA_HAP2 (
        FCSGX_CLEANGENOME_HAP2.out.cleaned,
        "${scaffolder_suffix}.hap2.tiara"
    )
    ch_versions = ch_versions.mix(TIARA_TIARA_HAP2.out.versions.first())

    //
    // MODULE: Run BBmap filterbyname
    //
    ch_bbmap_filterbyname_hap1_in = FCSGX_CLEANGENOME_HAP1.out.cleaned.join(TIARA_TIARA_HAP1.out.classifications)
    ch_bbmap_filterbyname_hap2_in = FCSGX_CLEANGENOME_HAP2.out.cleaned.join(TIARA_TIARA_HAP2.out.classifications)

    BBMAP_FILTERBYNAME_HAP1 (
        ch_bbmap_filterbyname_hap1_in,
        "2.tiara.hap1"
    )
    ch_versions = ch_versions.mix(BBMAP_FILTERBYNAME_HAP1.out.versions.first())

    BBMAP_FILTERBYNAME_HAP2 (
        ch_bbmap_filterbyname_hap2_in,
        "2.tiara.hap2"
    )
    ch_versions = ch_versions.mix(BBMAP_FILTERBYNAME_HAP2.out.versions.first())

    emit:
    // Final cleaned scaffolds - what you'll use downstream
    hap1_clean_scaffolds = BBMAP_FILTERBYNAME_HAP1.out.scaffolds
    hap2_clean_scaffolds = BBMAP_FILTERBYNAME_HAP2.out.scaffolds
    
    // Intermediate outputs if needed elsewhere
    hap1_fcs_cleaned = FCSGX_CLEANGENOME_HAP1.out.cleaned
    hap2_fcs_cleaned = FCSGX_CLEANGENOME_HAP2.out.cleaned
    hap1_contaminants = FCSGX_CLEANGENOME_HAP1.out.contaminants
    hap2_contaminants = FCSGX_CLEANGENOME_HAP2.out.contaminants
    
    // Reports
    hap1_fcs_report = FCS_FCSGX_HAP1.out.fcs_gx_report
    hap2_fcs_report = FCS_FCSGX_HAP2.out.fcs_gx_report
    hap1_tiara_classifications = TIARA_TIARA_HAP1.out.classifications
    hap2_tiara_classifications = TIARA_TIARA_HAP2.out.classifications
    
    versions = ch_versions
}