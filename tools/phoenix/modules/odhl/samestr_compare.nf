process SAMESTR_COMPARE {
    tag "$meta.id"
    label 'process_medium'
    container 'quay.io/biocontainers/samestr:1.2024.2.post1--pyhdfd78af_0'

    input:
    path(filter_npy)
    path(filter_txt)
    path(samestr_db)

    output:
    tuple val(meta), path('out_compare/*bam'), emit: something

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    samestr compare \
        --input-files ${filter_npy} \
        --input-names ${filter.txt} \
        --marker-dir ${samestr_db}/ \
        --nprocs 30 \
        --output-dir out_compare/
    """
}