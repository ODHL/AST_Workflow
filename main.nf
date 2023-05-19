#!/usr/bin/env nextflow
/*
========================================================================================
    ODH/AST
========================================================================================
    Github : https://github.com/ODHL/AST_Workflow
----------------------------------------------------------------------------------------
*/

nextflow.enable.dsl = 2

/*
========================================================================================
    VALIDATE & PRINT PARAMETER SUMMARY
========================================================================================
*/

WorkflowMain.initialise(workflow, params, log)

/*
========================================================================================
    NAMED WORKFLOW FOR PIPELINE
========================================================================================
*/

include { ANALYSIS_RUN                } from './workflows/analysis'
include { ANALYSIS_RUN_MINI           } from './workflows/analysis_mini'

//
// WORKFLOW: Analysis pipeline
//
workflow ANALYSIS {
    main:
        ANALYSIS_RUN ()
    emit:
        scaffolds        = ANALYSIS_RUN.out.scaffolds
        // trimmed_reads    = ANALYSIS_RUN.out.trimmed_reads
        // mlst             = ANALYSIS_RUN.out.mlst
        // amrfinder_report = ANALYSIS_RUN.out.amrfinder_report
        // gamma_ar         = ANALYSIS_RUN.out.gamma_ar
}

workflow ANALYSIS_PARTIAL {
    main:
        ANALYSIS_RUN_MINI ()
    emit:
        scaffolds        = ANALYSIS_RUN_MINI.out.scaffolds
        // trimmed_reads    = ANALYSIS_RUN.out.trimmed_reads
        // mlst             = ANALYSIS_RUN.out.mlst
        // amrfinder_report = ANALYSIS_RUN.out.amrfinder_report
        // gamma_ar         = ANALYSIS_RUN.out.gamma_ar
}