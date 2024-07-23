/*
========================================================================================
    VALIDATE INPUTS
========================================================================================
*/

/*
========================================================================================
    SETUP
========================================================================================
*/

// Info required for completion email and summary
def multiqc_report = []

/*
========================================================================================
    CONFIG FILES
========================================================================================
*/

/*
========================================================================================
    IMPORT LOCAL MODULES
========================================================================================
*/

include { OUTBREAK_REPORT                       } from '../modules/odhl/outbreak' // Run CFSAN-SNP Pipeline
//include { BASIC                       } from '../modules/odhl/basic' // Run CFSAN-SNP Pipeline

/*
========================================================================================
    IMPORT LOCAL SUBWORKFLOWS
========================================================================================
*/
include { INPUT_CHECK                    } from '../subworkflows/odhl/input_check_tree'

/*
========================================================================================
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
========================================================================================
*/

//
// MODULE: Installed directly from nf-core/modules
//

/*
========================================================================================
    GROOVY FUNCTIONS
========================================================================================
*/

def add_empty_ch(input_ch) {
    meta_id = input_ch[0]
    output_array = [ meta_id, input_ch[1], input_ch[2], []]
    return output_array
}

// Groovy funtion to make [ meta.id, [] ] - just an empty channel
def create_empty_ch(input_for_meta) { // We need meta.id associated with the empty list which is why .ifempty([]) won't work
    meta_id = input_for_meta[0]
    output_array = [ meta_id, [] ]
    return output_array
}

/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

workflow CREATE_REPORT {
    take:
        ch_input

    main:
        // Generate OUTBREAK REPORT
        OUTBREAK_REPORT (
            params.projectID,
            params.outbreakScript,
            params.logoFile,
            params.ar_predictions,
            params.core_stats,
            params.snp_dist,
            params.core_tree,
            params.ar_config,
            params.metadata,
            params.pipe_report
        )

    emit:
        report_outbreak            = OUTBREAK_REPORT.out.report
}

/*
========================================================================================
    COMPLETION EMAIL AND SUMMARY
========================================================================================
*/

workflow.onComplete {
    if (count == 0){
        if (params.email || params.email_on_fail) {
            NfcoreTemplate.email(workflow, params, summary_params, projectDir, log)
        }
        NfcoreTemplate.summary(workflow, params, log)
        count++
    }
}

/*
========================================================================================
    THE END
========================================================================================
*/