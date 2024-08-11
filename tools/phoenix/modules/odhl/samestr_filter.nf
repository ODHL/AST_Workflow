process SAMESTR_FILTER {
    tag "$meta.id"
    label 'process_medium'
    container 'quay.io/biocontainers/samestr:1.2024.2.post1--pyhdfd78af_0'

    input:
    tuple val(meta), path(merge_npy)
    tuple val(meta), path(merge_txt)
    path(samestr_db)

    output:
    tuple val(meta), path('out_filter/*.npy'), emit: filter_npy
    tuple val(meta), path('out_filter/*.txt'), emit: filter_txt

    script:
    def args = task.ext.args ?: ''
    """
    samestr filter \
        --input-files ${merge_npy} \
        --input-names ${merge_txt} \
        --marker-dir ${samestr_db}/ \
        --clade-min-n-hcov 5000 \
        --clade-min-samples 2 \
        --marker-trunc-len 20 \
        --global-pos-min-n-vcov 2 \
        --sample-pos-min-n-vcov 5 \
        --sample-var-min-f-vcov 0.1 \
        --nprocs 30 \
        --output-dir out_filter/
    """
}