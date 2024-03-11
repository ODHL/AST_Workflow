process SAMESTR_CONVERT {
    tag "$meta.id"
    label 'process_medium'
    container 'quay.io/biocontainers/samestr:1.2024.2.post1--pyhdfd78af_0'

    input:
    tuple val(meta), path(bam)
    tuple val(meta), path(profile)
    path(samestr_db)

    output:
    tuple val(meta), path('out_convert/*/*.txt'), emit: convert

    script:
    def args = task.ext.args ?: ''
    """
    samestr convert \
    --input-files $bam \
    --marker-dir ${samestr_db}/ \
    --nprocs 30 \
    --min-vcov 5 \
    --output-dir out_convert/
    """
}