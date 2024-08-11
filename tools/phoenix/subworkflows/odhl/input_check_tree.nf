//
// Check input samplesheet and get read channels
//

include { SAMPLESHEET_CHECK as SAMPLESHEET_CHECK_GFF } from '../../modules/odhl/samplesheet_check_tree'
include { SAMPLESHEET_CHECK as SAMPLESHEET_CHECK_FQ } from '../../modules/odhl/samplesheet_check_tree'

workflow INPUT_CHECK {
    take:
    samplesheet // file: /path/to/samplesheet.csv

    main:
    SAMPLESHEET_CHECK_GFF ( samplesheet )
        .csv
        .splitCsv ( header:true, sep:',' )
        .map { create_fastq_channels(it) }
        .set { reads }

    emit:
    reads                                     // channel: [ val(meta), [fastq1,fast2], [ gffs ] ]
    valid_samplesheet = SAMPLESHEET_CHECK_GFF.out.csv
}

// Function to get list of [ meta, [fastq1,fastq2], [ gff ] ]
def create_fastq_channels(LinkedHashMap row) {
    def meta = [:]
    meta.id           = row.sample

    def array = []
    if (!file(row.fastq_1).exists()) {
        exit 1, "ERROR: Please check input samplesheet -> Read 1 FastQ file does not exist!\n${row.fastq_1}"
    }
    if (!file(row.fastq_2).exists()) {
        exit 1, "ERROR: Please check input samplesheet -> Read 2 FastQ file does not exist!\n${row.fastq_2}"
    }
    if (!file(row.gff).exists()) {
        exit 1, "ERROR: Please check input samplesheet -> GFF file does not exist!\n${row.gff}"
    }
    array = [ meta, [ file(row.fastq_1), file(row.fastq_2) ], [file(row.gff)] ]
    return array
}
