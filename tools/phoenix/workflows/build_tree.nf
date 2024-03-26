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
include { CFSAN                          } from '../modules/odhl/cfsan' // Run CFSAN-SNP Pipeline
include { ROARY                          } from '../modules/odhl/roary' // Perform core genome alignment using Roary
include { TREE                           } from '../modules/odhl/core_genome_tree' //Infer ML tree from core genome alignment using IQ-TREE
include { SAMESTR_DB                     } from '../modules/odhl/samestr_db'
include { MOTUS                          } from '../modules/odhl/motus'
include { SAMTOOLS_SORT                  } from '../modules/odhl/samtools_sort'
include { SAMESTR_CONVERT                } from '../modules/odhl/samestr_convert'
include { SAMESTR_EXTRACT                } from '../modules/odhl/samestr_extract'
include { SAMESTR_MERGE                  } from '../modules/odhl/samestr_merge'

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

workflow BUILD_TREE {
    take:
        ch_input

    main:
        // Allow outdir to be relative
        outdir_path = Channel.fromPath(params.outdir, relative: true)

        INPUT_CHECK (
            ch_input,
        )
        
        // create gff channel
        // remove samples that are *.filtered.scaffolds.fa.gz
        ch_gff = INPUT_CHECK.out.reads.flatten().filter( it -> (it =~ 'gff') )
        // ch_gff.view()

        // Generate SNP dist matrix
        CFSAN (
            params.treedir,
            params.ardb,
            Channel.from(ch_snp_config)
        )

        // Generate core genome statistics
        ROARY (
            ch_gff.collect(),
            params.percent_id
        )

        // Generate core genome tree
        TREE (
            ROARY.out.aln
        )

    emit:
        valid_samplesheet            = INPUT_CHECK.out.valid_samplesheet
        distmatrix  = CFSAN.out.distmatrix
        core_stats  = ROARY.out.core_stats
        tree        = TREE.out.genome_tree
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