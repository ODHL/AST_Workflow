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

ch_multiqc_config        = file("$projectDir/assets/multiqc_config.yaml", checkIfExists: true)
ch_multiqc_custom_config = params.multiqc_config ? Channel.fromPath(params.multiqc_config) : Channel.empty()

/*
========================================================================================
    IMPORT LOCAL MODULES
========================================================================================
*/

include { ASSET_CHECK                    } from '../modules/local/asset_check'
include { ROARY                          } from '../modules/local/roary' // Perform core genome alignment using Roary
include { TREE                           } from '../modules/local/core_genome_tree' //Infer ML tree from core genome alignment using IQ-TREE

/*
========================================================================================
    IMPORT LOCAL SUBWORKFLOWS
========================================================================================
*/

include { CREATE_INPUT_CHANNEL                     } from '../subworkflows/local/create_input_tree_channel'

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

workflow CREATE_TREE {
    take:
        ch_input
        ch_input_indir

    main:
        ch_versions = Channel.empty() // Used to collect the software versions
        // Allow outdir to be relative
        outdir_path = Channel.fromPath(params.outdir, relative: true)

        CREATE_INPUT_CHANNEL (
            ch_input_indir, ch_input, ch_versions
        )
        ch_versions = ch_versions.mix(CREATE_INPUT_CHANNEL.out.versions)

        // Generate core genome statistics
        ROARY (
            CREATE_INPUT_CHANNEL.out.gff_ch.collect(), 
        )

        // Generate core genome tree
        TREE (
            ROARY.out.aln
        )

    emit:
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