/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { HIFIADAPTERFILT                                } from '../modules/local/hifiadapterfilt/main'
include { FASTQC as FASTQC_HIFI                          } from '../modules/nf-core/fastqc/main'
include { FASTQC as FASTQC_HIC                           } from '../modules/nf-core/fastqc/main'
include { MERYL_COUNT                                    } from '../modules/nf-core/meryl/count/main'
include { MERYL_HISTOGRAM                                } from '../modules/nf-core/meryl/histogram/main'
include { GENOMESCOPE2                                   } from '../modules/nf-core/genomescope2/main'
include { CAT_HIC                                        } from '../modules/local/cat_hic/main'
include { HIFIASM                                        } from '../modules/nf-core/hifiasm/main'
include { GFASTATS as GFASTATS_HAP1                      } from '../modules/nf-core/gfastats/main'
include { GFASTATS as GFASTATS_HAP2                      } from '../modules/nf-core/gfastats/main'
include { BUSCO_BUSCO                                    } from '../modules/nf-core/busco/busco/main'
include { BUSCO_GENERATEPLOT                             } from '../modules/nf-core/busco/generateplot/main'
include { MERQURY                                        } from '../modules/nf-core/merqury/main'
include { OMNIC as OMNIC_HAP1                            } from '../subworkflows/local/omnic/main'
include { OMNIC as OMNIC_HAP2                            } from '../subworkflows/local/omnic/main'
include { YAHS as YAHS_HAP1                              } from '../modules/nf-core/yahs/main'
include { YAHS as YAHS_HAP2                              } from '../modules/nf-core/yahs/main'
include { FCS_FCSGX as FCS_FCSGX_HAP1                    } from '../modules/nf-core/fcs/fcsgx/main'
include { FCS_FCSGX as FCS_FCSGX_HAP2                    } from '../modules/nf-core/fcs/fcsgx/main'
include { TIARA_TIARA as TIARA_TIARA_HAP1                } from '../modules/nf-core/tiara/tiara/main'
include { TIARA_TIARA as TIARA_TIARA_HAP2                } from '../modules/nf-core/tiara/tiara/main'
include { BBMAP_FILTERBYNAME as BBMAP_FILTERBYNAME_HAP1  } from '../modules/local/bbmap/filterbyname/main'
include { BBMAP_FILTERBYNAME as BBMAP_FILTERBYNAME_HAP2  } from '../modules/local/bbmap/filterbyname/main'
include { GFASTATS as GFASTATS_HAP1_FINAL                } from '../modules/nf-core/gfastats/main'
include { GFASTATS as GFASTATS_HAP2_FINAL                } from '../modules/nf-core/gfastats/main'
include { BUSCO_BUSCO as BUSCO_BUSCO_FINAL               } from '../modules/nf-core/busco/busco/main'
include { BUSCO_GENERATEPLOT as BUSCO_GENERATEPLOT_FINAL } from '../modules/nf-core/busco/generateplot/main'
include { CAT_SCAFFOLDS                                  } from '../modules/local/cat_scaffolds/main'
include { TAR                                            } from '../modules/local/tar/main'
include { COVERAGE_TRACKS                                } from '../subworkflows/local/coverage_tracks/main'
include { TIDK_EXPLORE                                   } from '../modules/nf-core/tidk/explore/main'
include { OMNIC as OMNIC_HAP1_FINAL                      } from '../subworkflows/local/omnic/main'
include { OMNIC as OMNIC_HAP2_FINAL                      } from '../subworkflows/local/omnic/main'
include { OMNIC as OMNIC_DUAL_HAP                        } from '../subworkflows/local/omnic/main'
include { PRETEXTMAP as PRETEXTMAP_HAP_1                 } from '../modules/nf-core/pretextmap/main'
include { PRETEXTMAP as PRETEXTMAP_HAP_2                 } from '../modules/nf-core/pretextmap/main'
include { PRETEXTMAP as PRETEXTMAP_DUAL_HAP              } from '../modules/nf-core/pretextmap/main'
include { PRETEXTSNAPSHOT PRETEXTSNAPSHOT_HAP1           } from '../modules/nf-core/pretextsnapshot/main' 
include { PRETEXTSNAPSHOT PRETEXTSNAPSHOT_HAP2           } from '../modules/nf-core/pretextsnapshot/main' 
include { PRETEXTSNAPSHOT PRETEXTSNAPSHOT_DUAL_HAP       } from '../modules/nf-core/pretextsnapshot/main'  
include { MD5SUM as MD5SUM_OMNICS_HAP1                   } from '../modules/local/md5sum/main'
include { MD5SUM as MD5SUM_OMNICS_HAP2                   } from '../modules/local/md5sum/main'
include { MD5SUM as MD5SUM_YAHS_HAP1                     } from '../modules/local/md5sum/main'
include { MD5SUM as MD5SUM_YAHS_HAP2                     } from '../modules/local/md5sum/main'
//include { RCLONE                                         } from '../modules/local/rclone/main'
include { MULTIQC                                        } from '../modules/nf-core/multiqc/main'
include { paramsSummaryMap                               } from 'plugin/nf-validation'
include { paramsSummaryMultiqc                           } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML                         } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText                         } from '../subworkflows/local/utils_oceangenomesrefgenomes_pipeline'
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow REFGENOMES {

    take:
    ch_samplesheet // channel: samplesheet read in from --input

    main:

    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()
    ch_rclone_in = Channel.empty()

    ch_hifi = ch_samplesheet
        .map {
            meta ->
                meta = meta[0]
                meta.id = meta.sample + "_" + meta.date + "." + meta.version
                return [ meta, meta.hifi_dir ]
        }

    ch_hic = ch_samplesheet
        .map {
            meta ->
                if (meta.hic_dir[0] != null) {
                    meta = meta[0]
                    meta.id = meta.sample + "_" + meta.date + "." + meta.version
                    return [ meta, meta.hic_dir ]
                }
        }

    //
    // MODULE: Run HiFiAdapterFilt
    //
    HIFIADAPTERFILT (
        ch_hifi
    )
    ch_versions = ch_versions.mix(HIFIADAPTERFILT.out.versions.first())

    //
    // MODULE: Run FastQC on HiFi fastqc files
    //
    FASTQC_HIFI (
        HIFIADAPTERFILT.out.reads,
        "hifi"
    )
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC_HIFI.out.zip)
    ch_versions = ch_versions.mix(FASTQC_HIFI.out.versions.first())

    //
    // MODULE: Run Meryl
    //
    MERYL_COUNT (
        HIFIADAPTERFILT.out.reads,
        params.kvalue
    )
    ch_versions = ch_versions.mix(MERYL_COUNT.out.versions.first())

    //
    // MODULE: Run Meryl histogram
    //
    MERYL_HISTOGRAM (
        MERYL_COUNT.out.meryl_db,
        params.kvalue
    )
    ch_versions = ch_versions.mix(MERYL_HISTOGRAM.out.versions.first())

    //
    // MODULE: Run Genomescope2
    //
    GENOMESCOPE2 (
        MERYL_HISTOGRAM.out.hist
    )
    ch_versions = ch_versions.mix(GENOMESCOPE2.out.versions.first())

    //
    // MODULE: Concatenate Hi-C files together for cases when there is multiple R1 and multiple R2 files
    //
    CAT_HIC (
        ch_hic
    )

    //
    // MODULE: Run FastQC on Hi-C fastqc files
    //
    FASTQC_HIC (
        CAT_HIC.out.cat_files,
        "hic"
    )
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC_HIC.out.zip)
    ch_versions = ch_versions.mix(FASTQC_HIC.out.versions.first())

    //
    // MODULE: Run Hifiasm
    //
    ch_hifiasm_in = HIFIADAPTERFILT.out.reads.join(CAT_HIC.out.cat_files)
        .map {
            meta, hifi, hic ->
                return [ meta, hifi, hic[0], hic[1] ]
        }

    HIFIASM (
        ch_hifiasm_in,
        "0.hifiasm",
        [],
        []
    )
    ch_versions = ch_versions.mix(HIFIASM.out.versions.first())

    //
    // MODULE: Run Gfastats
    //
    ch_gfastats_hap1_in = HIFIASM.out.hap1_contigs.join(GENOMESCOPE2.out.summary)
    ch_gfastats_hap2_in = HIFIASM.out.hap2_contigs.join(GENOMESCOPE2.out.summary)

    GFASTATS_HAP1 (
        ch_gfastats_hap1_in,
        "fasta",
        "",
        "hap1",
        "0.hifiasm",
        [],
        [],
        [],
        []
    )
    ch_versions = ch_versions.mix(GFASTATS_HAP1.out.versions.first())

    GFASTATS_HAP2 (
        ch_gfastats_hap2_in,
        "fasta",
        "",
        "hap2",
        "0.hifiasm",
        [],
        [],
        [],
        []
    )
    ch_versions = ch_versions.mix(GFASTATS_HAP2.out.versions.first())

    ch_contig_assemblies = GFASTATS_HAP1.out.assembly.join(GFASTATS_HAP2.out.assembly)
        .map {
            meta, hap1_contigs, hap2_contigs ->
                return [ meta, [ hap1_contigs, hap2_contigs ] ]
        }

    //
    // MODULE: Run Busco
    //
    BUSCO_BUSCO (
        ch_contig_assemblies,
        params.buscomode,
        params.buscodb,
        "0.hifiasm",
        []
    )
    ch_versions = ch_versions.mix(BUSCO_BUSCO.out.versions.first())

    //
    // MODULE: Run Busco generate_plot
    //
    BUSCO_GENERATEPLOT (
        BUSCO_BUSCO.out.short_summaries_txt,
        "0.hifiasm"
    )
    ch_versions = ch_versions.mix(BUSCO_GENERATEPLOT.out.versions.first())

    //
    // MODULE: Run Merqury
    //
    ch_merqury_in = MERYL_COUNT.out.meryl_db.join(ch_contig_assemblies)

    MERQURY (
        ch_merqury_in,
        "contigs",
        "0.hifiasm"
    )
    ch_versions = ch_versions.mix(MERQURY.out.versions.first())

    //
    // SUBWORKFLOW: Run omnic workflow
    //
    ch_omnic_hap1_in = CAT_HIC.out.cat_files.join(ch_contig_assemblies)
        .map {
            meta, reads, assemblies ->
                return [ meta, reads, assemblies[0] ]
        }

    ch_omnic_hap2_in = CAT_HIC.out.cat_files.join(ch_contig_assemblies)
        .map {
            meta, reads, assemblies ->
                return [ meta, reads, assemblies[1] ]
        }

    OMNIC_HAP1 (
        ch_omnic_hap1_in,
        "hap1"
    )
    ch_versions = ch_versions.mix(OMNIC_HAP1.out.versions.first())

    OMNIC_HAP2 (
        ch_omnic_hap2_in,
        "hap2"
    )
    ch_versions = ch_versions.mix(OMNIC_HAP2.out.versions.first())

    //
    // MODULE: Run Yahs
    //
    ch_yahs_hap1_in = OMNIC_HAP1.out.bam.join(GFASTATS_HAP1.out.assembly).join(OMNIC_HAP1.out.fai)
    ch_yahs_hap2_in = OMNIC_HAP2.out.bam.join(GFASTATS_HAP2.out.assembly).join(OMNIC_HAP2.out.fai)

    YAHS_HAP1 (
        ch_yahs_hap1_in,
        ".1.yahs.hap1"
    )
    ch_versions = ch_versions.mix(YAHS_HAP1.out.versions.first())

    YAHS_HAP2 (
        ch_yahs_hap1_in,
        ".1.yahs.hap2"
    )
    ch_versions = ch_versions.mix(YAHS_HAP2.out.versions.first())

    //
    // MODULE: Run Fcsgx
    //
    FCS_FCSGX_HAP1 (
        YAHS_HAP1.out.scaffolds_fasta,
        params.gxdb,
        ".1.yahs.hap1.NCBI"
    )
    ch_versions = ch_versions.mix(FCS_FCSGX_HAP1.out.versions.first())

    FCS_FCSGX_HAP2 (
        YAHS_HAP2.out.scaffolds_fasta,
        params.gxdb,
        ".1.yahs.hap2.NCBI"
    )
    ch_versions = ch_versions.mix(FCS_FCSGX_HAP2.out.versions.first())

    //
    // MODULE: Run Tiara
    //
    TIARA_TIARA_HAP1 (
        YAHS_HAP1.out.scaffolds_fasta,
        ".1.yahs.hap1.tiara"
    )
    ch_versions = ch_versions.mix(TIARA_TIARA_HAP1.out.versions.first())

    TIARA_TIARA_HAP2 (
        YAHS_HAP2.out.scaffolds_fasta,
        ".1.yahs.hap2.tiara"
    )
    ch_versions = ch_versions.mix(TIARA_TIARA_HAP2.out.versions.first())

    //
    // MODULE: Run BBmap filterbyname
    //
    ch_bbmap_filterbyname_hap1_in = YAHS_HAP1.out.scaffolds_fasta.join(TIARA_TIARA_HAP1.out.classifications)
    ch_bbmap_filterbyname_hap2_in = YAHS_HAP2.out.scaffolds_fasta.join(TIARA_TIARA_HAP2.out.classifications)

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

    
    //
    // MODULE: Run Gfastats again
    //


    ch_gfastats2_hap1_in = BBMAP_FILTERBYNAME_HAP1.out.scaffolds.join(GENOMESCOPE2.out.summary)
    ch_gfastats2_hap2_in = BBMAP_FILTERBYNAME_HAP2.out.scaffolds.join(GENOMESCOPE2.out.summary)
    ch_gfastats2_hap1_in.view()
    ch_gfastats2_hap1_in.view()


    GFASTATS_HAP1_FINAL (
        ch_gfastats2_hap1_in,
        "fa",
        "",
        "hap1_scaffolds",
        "2.tiara",
        [],
        [],
        [],
        []
    )
    ch_versions = ch_versions.mix(GFASTATS_HAP1_FINAL.out.versions.first())


    GFASTATS_HAP2_FINAL (
        ch_gfastats2_hap2_in,
        "fa",
        "",
        "hap2_scaffolds",
        "2.tiara",
        [],
        [],
        [],
        []
    )
    ch_versions = ch_versions.mix(GFASTATS_HAP2_FINAL.out.versions.first())

    
    
    //
    // MODULE: Run Busco again
    //

   // busco_final_assemblies_ch=BBMAP_FILTERBYNAME_HAP1.out.scaffolds.join(BBMAP_FILTERBYNAME_HAP2.out.scaffolds)
    //        .map {
    //        meta, hap1_scaffolds, hap2_scaffolds ->
     //           return [ meta, [ hap1_scaffolds, hap2_scaffolds ] ]
     //   }

    //BUSCO_BUSCO_FINAL (
    //    busco_final_assemblies_ch,
    //    params.buscomode,
    //    params.buscodb,
    //    "2.tiara",
    //    []
   // )
   //ch_versions = ch_versions.mix(BUSCO_BUSCO_FINAL.out.versions.first())

    //
    // MODULE: Run Busco generate_plot again
    //
   // BUSCO_GENERATEPLOT_FINAL (
   //     BUSCO_BUSCO_FINAL.out.short_summaries_txt,
   //     "2.tiara."
   // )
   // ch_versions = ch_versions.mix(BUSCO_GENERATEPLOT_FINAL.out.versions.first())

    //
    // MODULE: Rename, and concatenate scaffolds
    //
   // ch_filtered_scaffolds = BBMAP_FILTERBYNAME_HAP1.out.scaffolds.join(BBMAP_FILTERBYNAME_HAP2.out.scaffolds)
  //      .map {
  //          meta, hap1_scaffolds, hap2_scaffolds ->
   //             return [ meta, [ hap1_scaffolds, hap2_scaffolds ] ]
   //     }

   // CAT_SCAFFOLDS (
   //    ch_filtered_scaffolds,
    //  ".2.tiara.hap1.hap2"
   // )
  // ch_versions = ch_versions.mix(CAT_SCAFFOLDS.out.versions.first())


    //
    // SUBWORKFLOW: Run coverage tracks
    //

    ch_coverage_tracks_in = HIFIADAPTERFILT.out.reads.join(CAT_SCAFFOLDS.out.cat_file)
        .map {
            meta, reads, assemblies ->
                return [ meta, reads, assemblies[2] ]
            }
    
     COVERAGE_TRACKS (
        ch_coverage_tracks_in
    )
    ch_versions = ch_versions.mix(COVERAGE_TRACKS.out.versions.first())

    //
    // MODULE: Run TIDK 
    //

    TIDK_EXPLORE ( CAT_SCAFFOLDS.out.cat_file )
    ch_versions = ch_versions.mix(TIDK_EXPLORE.out.versions.first())
    
    //
    // SUBWORFLOW: Run omnic again
    //

    ch_omnic_hap1_in = CAT_HIC.out.cat_files.join(CAT_SCAFFOLDS.out.hap1_scaffold)
        .map {
            meta, reads, assemblies ->
                return [ meta, reads, assemblies[0] ]
        }

    ch_omnic_hap2_in = CAT_HIC.out.cat_files.join(CAT_SCAFFOLDS.out.hap2_scaffold)
        .map {
            meta, reads, assemblies ->
                return [ meta, reads, assemblies[1] ]
        }

    ch_omic_dual_in = CAT_HIC.out.cat_files.join.(CAT_SCAFFOLDS.out.cat_file)
            .map {
            meta, reads, assemblies ->
                return [ meta, reads, assemblies[2] ]
            }

   OMNIC_HAP1_FINAL (
        ch_omnic_hap1_in,
        "hap1"
    )
    ch_versions = ch_versions.mix(OMNIC_HAP1_FINAL.out.versions.first())

    OMNIC_HAP2_FINAL (
        ch_omnic_hap2_in,
        "hap2"
    )
    ch_versions = ch_versions.mix(OMNIC_HAP2_FINAL.out.versions.first())

    OMNIC_DUAL_HAP (
        ch_omic_dual_in
        'dual'
    )

    ch_versions = ch_versions.mix(OMNIC_DUAL_HAP.out.versions.first())

    //
    // MODULE: Run Pretext Map
    ///

    PRETEXTMAP_HAP_1 (OMNIC_HAP1_FINAL.out.bam)
    
    ch_versions = ch_versions.mix(PRETEXTMAP_HAP_1.out.versions.first())
    
    PRETEXTMAP_HAP_2 (OMNIC_HAP2_FINAL.out.bam)
    
    ch_versions = ch_versions.mix(PRETEXTMAP_HAP_1.out.versions.first())
    
    PRETEXTMAP_DUAL_HAP (OMNIC_DUAL_HAP.out.bam)
    
    ch_versions = ch_versions.mix(PRETEXTMAP_HAP_1.out.versions.first())
    
    //
    // MODULE: Run Pretext snapshot
    //

    PRETEXTSNAPSHOT_HAP1 (PRETEXTMAP_HAP_1.out.pretext)  
    
    ch_versions = ch_versions.mix(PRETEXTSNAPSHOT_HAP1.out.versions.first())

    PRETEXTSNAPSHOT_HAP2 (PRETEXTMAP_HAP_2.out.pretext)
    
    ch_versions = ch_versions.mix(PRETEXTSNAPSHOT_HAP2.out.versions.first())

    PRETEXTSNAPSHOT_DUAL_HAP (PRETEXTMAP_DUAL_HAP.out.pretext)
    
    ch_versions = ch_versions.mix(PRETEXTSNAPSHOT_DUAL_HAP.out.versions.first())

    
    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(storeDir: "${params.outdir}/pipeline_info", name: 'nf_core_pipeline_software_mqc_versions.yml', sort: true, newLine: true)
        .set { ch_collated_versions }

    //
    // MODULE: MultiQC
    //
    ch_multiqc_config                     = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config              = params.multiqc_config ? Channel.fromPath(params.multiqc_config, checkIfExists: true) : Channel.empty()
    ch_multiqc_logo                       = params.multiqc_logo ? Channel.fromPath(params.multiqc_logo, checkIfExists: true) : Channel.empty()
    summary_params                        = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary                   = Channel.value(paramsSummaryMultiqc(summary_params))
    ch_multiqc_custom_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = Channel.value(methodsDescriptionText(ch_multiqc_custom_methods_description))

    ch_multiqc_files                      = ch_multiqc_files.mix(BUSCO_GENERATEPLOT.out.png)
    //ch_multiqc_files                      = ch_multiqc_files.mix(BUSCO_GENERATEPLOT_FINAL.out.png)
    ch_multiqc_files                      = ch_multiqc_files.mix(GENOMESCOPE2.out.linear_plot_png)
    ch_multiqc_files                      = ch_multiqc_files.mix(GENOMESCOPE2.out.transformed_linear_plot_png)
    ch_multiqc_files                      = ch_multiqc_files.mix(GENOMESCOPE2.out.log_plot_png)
    ch_multiqc_files                      = ch_multiqc_files.mix(GENOMESCOPE2.out.transformed_log_plot_png)
    ch_multiqc_files                      = ch_multiqc_files.mix(MERQURY.out.spectra_cn_fl_png)
    ch_multiqc_files                      = ch_multiqc_files.mix(MERQURY.out.spectra_cn_ln_png)
    ch_multiqc_files                      = ch_multiqc_files.mix(MERQURY.out.spectra_cn_st_png)
    ch_multiqc_files                      = ch_multiqc_files.mix(MERQURY.out.spectra_asm_fl_png)
    ch_multiqc_files                      = ch_multiqc_files.mix(MERQURY.out.spectra_asm_ln_png)
    ch_multiqc_files                      = ch_multiqc_files.mix(MERQURY.out.spectra_asm_st_png)
    ch_multiqc_wf_summary                 = ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml')
    ch_multiqc_versions                   = ch_collated_versions
    ch_multiqc_method_desc                = ch_methods_description.collectFile(name: 'methods_description_mqc.yaml', sort: false)

    ch_multiqc_files = ch_multiqc_files
        .groupTuple()
        .map {
            meta, files ->
                return [ meta, files[0], files[1], files[2], files[3], files[4], files[5], files[6], files[7], files[8], files[9], files[10], files[11], files[12], files[13], files[14], files[15] ]
        }

    MULTIQC (
        ch_multiqc_files,
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList(),
        ch_multiqc_wf_summary.first(),
        ch_multiqc_versions.first(),
        ch_multiqc_method_desc.first()
    )


    emit:
    multiqc_report = MULTIQC.out.report.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
