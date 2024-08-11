process SAMPLESHEET_CHECK {
    tag "$samplesheet"
    label 'process_single'

    input:
    path samplesheet

    output:
    path('*.valid.csv'), emit: csv

    """
    cp $samplesheet samplesheet.valid.csv
    """
}
