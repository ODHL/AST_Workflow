process SAMESTR_STATS {
    tag "$meta.id"
    label 'process_medium'
    container 'quay.io/biocontainers/samestr:1.2024.2.post1--pyhdfd78af_0'

    input:
    tuple val(meta), path(filter_npy)
    tuple val(meta), path(filter_txt)
    path(samestr_db)

    output:
    tuple val(meta), path('out_stats_/*bam'), emit: bams

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    samestr stats \
        --input-files ${filter_npy} \
        --input-names ${filter_txt} \
        --marker-dir ${samestr_db}/ \
        --nprocs 30 \
        --output-dir out_stats_/
    """
}