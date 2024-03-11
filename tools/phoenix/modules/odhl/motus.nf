process MOTUS {
    tag "$meta.id"
    label 'process_medium'
    container 'quay.io/biocontainers/motus:3.1.0--pyhdfd78af_0'

    input:
    path(db_motu_dir)
    tuple val(meta), path(reads), path(gff)

    output:
    tuple val(meta), path('*bam'), emit: bam
    tuple val(meta), path('*txt'), emit: profile

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """    
    gunzip -c ${reads[0]} > ${prefix}.R1.fastq
    gunzip -c ${reads[1]} > ${prefix}.R2.fastq

    motus profile \
        -f ${prefix}.R1.fastq -r ${prefix}.R2.fastq \
        -g 1 \
        -db ${db_motu_dir} \
        -n ${prefix} \
        -I ${prefix}.bam \
        -o ${prefix}.profile.txt 

    rm -rf mouts *fastq
    """
}