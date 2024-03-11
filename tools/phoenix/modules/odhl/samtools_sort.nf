process SAMTOOLS_SORT {
    tag "$meta.id"
    label 'process_medium'
    container 'bhklab/samtools-1.9.0:latest'

    input:
    tuple val(meta), path(bam)

    output:
    tuple val(meta), path('sorted/*.bam'), emit: bam

    script:
    def args = task.ext.args ?: ''
    """
    mkdir sorted
    samtools sort ${bam} -o sorted/${bam}
    """
}