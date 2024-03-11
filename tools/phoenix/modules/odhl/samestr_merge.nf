process SAMESTR_MERGE {
    tag "$meta.id"
    label 'process_medium'
    container 'quay.io/biocontainers/samestr:1.2024.2.post1--pyhdfd78af_0'

    input:
    path(extract)
    tuple val(meta), path(convert)
    path(samestr_db)

    output:
    tuple val(meta), path('out_merge/*.npy'), emit: merged_npy
    tuple val(meta), path('out_merg/e*.txt'), emit: merged_txt

    script:
    def args = task.ext.args ?: ''
    """
    samestr merge \
        --input-files ${extract} ${convert} \
        --marker-dir ${samestr_db} \
        --nprocs 30 \
        --output-dir out_merge/
    """
}