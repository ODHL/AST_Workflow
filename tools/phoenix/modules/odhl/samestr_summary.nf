process SAMESTR_SUMMARY {
    tag "$meta.id"
    label 'process_medium'
    container 'quay.io/biocontainers/samestr:1.2024.2.post1--pyhdfd78af_0'

    input:
    path(compare)
    path(bams)
    path(samestr_db)

    output:
    tuple val(meta), path('out_summarize/*bam'), emit: something

    script:
    def args = task.ext.args ?: ''
    """
    mkdir out_compare
    mv *something out_compare

    mkdir out_align
    mv *bam out_align

    samestr summarize \
        --input-dir out_compare/ \
        --tax-profiles-dir out_align/ \
        --marker-dir ${samestr_db}/ \
        --output-dir out_summarize/
    """
}