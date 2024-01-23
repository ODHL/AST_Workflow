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

include { ASSET_CHECK                    } from '../modules/local/asset_check'
include { CFSAN                          } from '../modules/local/cfsan' // Run CFSAN-SNP Pipeline
include { ROARY                          } from '../modules/local/roary' // Perform core genome alignment using Roary
include { TREE                           } from '../modules/local/core_genome_tree' //Infer ML tree from core genome alignment using IQ-TREE

/*
========================================================================================
    IMPORT LOCAL SUBWORKFLOWS
========================================================================================
*/
include { INPUT_CHECK                    } from '../subworkflows/local/input_check_tree'

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

workflow BUILD_TREE {
    take:
        ch_input

    main:
        // Allow outdir to be relative
        outdir_path = Channel.fromPath(params.outdir, relative: true)

        INPUT_CHECK (
            ch_input
        )
        
        // Generate SNP dist matrix
        CFSAN (
            params.treedir,
            params.ardb,
            Channel.from(ch_snp_config)
        )

        // Generate core genome statistics
        ROARY (
            INPUT_CHECK.out.gffs.collect(), 
        )

        // Generate core genome tree
        TREE (
            ROARY.out.aln
        )

    emit:
        distmatrix  = CFSAN.out.distmatrix
        core_stats  = ROARY.out.core_stats
        tree        = TREE.out.tree
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