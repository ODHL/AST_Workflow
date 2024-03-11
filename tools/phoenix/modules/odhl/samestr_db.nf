process SAMESTR_DB {
    tag "SAMESTR_DB"
    label 'process_medium'
    container 'quay.io/biocontainers/samestr:1.2024.2.post1--pyhdfd78af_0'

    input:
    path(marker_info1)
    path(marker_info2)
    path(marker_fna)
    path(marker_version)

    output:
    path(samestr_db) , emit: samestr_db

    script:
    def args = task.ext.args ?: ''

    """
    mkdir mouts
    mv db_mOTU_* mouts

    samestr db \
        --markers-info mouts/${marker_info1} mouts/${marker_info2} \
        --markers-fasta mouts/${marker_fna} \
        --db-version mouts/${marker_version} \
        --output-dir samestr_db/
    """
}