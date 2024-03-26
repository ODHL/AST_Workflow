/*
========================================================================================
    VALIDATE INPUTS
========================================================================================
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

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
ch_snp_config            = file("$projectDir/assets/snppipipeline.conf", checkIfExists: true)

/*
========================================================================================
    IMPORT LOCAL MODULES
========================================================================================
*/

include { SAMESTR_DB                     } from '../modules/odhl/samestr_db'
include { SAMESTR_EXTRACT                } from '../modules/odhl/samestr_extract'

/*
========================================================================================
    IMPORT LOCAL SUBWORKFLOWS
========================================================================================
*/

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

workflow BUILD_DBS {
    take:
        db_loc

    main:
        // Allow outdir to be relative
        outdir_path = Channel.fromPath(params.outdir, relative: true)

        // Make database from mOTUs markers.
        SAMESTR_DB(
            params.markers_info1,
            params.markers_info2,
            params.marker_fna,
            params.marker_version
        )

        // Extract SNV Profiles from Reference Genomes.
        SAMESTR_EXTRACT(
            params.ref_fasta1,
            params.ref_fasta2,
            SAMESTR_DB.out.samestr_db
        )

    emit:
        samestr_db  = SAMESTR_DB.out.samestr_db
        samestr_ext = SAMESTR_EXTRACT.out.extracted_db
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