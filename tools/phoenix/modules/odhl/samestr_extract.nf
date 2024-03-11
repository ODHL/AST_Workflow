process SAMESTR_EXTRACT {
    tag "extract"
    label 'process_medium'
    container 'quay.io/biocontainers/samestr:1.2024.2.post1--pyhdfd78af_0'

    input:
    path(ref1)
    path(ref2)
    path(samestr_db)

    output:
    path('out_extract/*.npz'), emit: extracted_db

    script:
    def args = task.ext.args ?: ''
    """
    samestr extract \
        --input-files $ref1 $ref2 \
        --marker-dir ${samestr_db}/ \
        --nprocs 30 \
        --clade ref_mOTU_v31_00259 \
        --output-dir out_extract/
    """
}