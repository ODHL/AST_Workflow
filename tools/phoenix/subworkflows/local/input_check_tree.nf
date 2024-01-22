//
// Check input samplesheet and get read channels
//

include { SAMPLESHEET_CHECK as SAMPLESHEET_CHECK_GFF } from '../../modules/local/samplesheet_check_tree'
include { SAMPLESHEET_CHECK as SAMPLESHEET_CHECK_FQ } from '../../modules/local/samplesheet_check_tree'

workflow INPUT_CHECK {
    take:
    samplesheet // file: /path/to/samplesheet.csv

    main:
    SAMPLESHEET_CHECK_GFF ( samplesheet )
        .csv
        .splitCsv ( header:true, sep:',' )
        .map { create_gff_paths (it) }
        .set { gffs }

    SAMPLESHEET_CHECK_FQ ( samplesheet )
        .csv
        .splitCsv ( header:true, sep:',' )
        .map { create_fqs_paths (it) }
        .set { fqs }

    emit:
    fqs
    gffs                                     // channel: [ val(meta), [ gffs ] ]
    valid_samplesheet = SAMPLESHEET_CHECK_GFF.out.csv
}

// Function to get list of [ meta, [ gff ] ]
def create_gff_paths(LinkedHashMap row) {
    def meta = [:]
    meta.id           = row.sample

    def array = []
    array = [file(row.gff) ]
    return array
}

def create_fqs_paths(LinkedHashMap row) {
    def meta = [:]
    meta.id           = row.sample

    def array = []
    array = [file(row.fq1),file(row.fq2)]
    return array
}