process GET_RAW_STATS {
    tag "$meta.id"
    label 'process_single'
    container 'quay.io/jvhagey/phoenix:base_v2.0.0'

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path('*_stats.txt'),           emit: raw_stats
    tuple val(meta), path('*_raw_read_counts.txt'), emit: combined_raw_stats
    path("versions.yml"),                           emit: versions

    script: // This script is bundled with the pipeline, in cdcgov/phoenix/bin/
    def prefix = task.ext.prefix ?: "${meta.id}"
    def container = task.container.toString() - "quay.io/jvhagey/phoenix:"
    """
    q30.py ${reads[0]} > ${prefix}_R1_stats.txt
    q30.py ${reads[1]} > ${prefix}_R2_stats.txt
    create_raw_stats_output.py -n ${prefix} -r1 ${prefix}_R1_stats.txt -r2 ${prefix}_R2_stats.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
        phoenix_base_container: ${container}
    END_VERSIONS
    """
}