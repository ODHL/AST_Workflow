process GRIPHIN {
    label 'process_low'
    container 'quay.io/jvhagey/phoenix:base_v2.0.2'

    input:
    path(summary_line_files)
    path(original_samplesheet)
    path(db)
    path(outdir)
    val(coverage)
    val(entry)
    val(scaffolds_entry)

    output:
    path("*_Summary.xlsx"),          emit: griphin_report
    path("*_Summary.tsv"),           emit: griphin_tsv_report
    path("Directory_samplesheet.csv"), emit: converted_samplesheet
    path("versions.yml"),            emit: versions

    script: // This script is bundled with the pipeline, in cdcgov/phoenix/bin/
    def phoenix = entry ? "--phoenix" : ""
    def scaffolds = scaffolds_entry ? "--scaffolds" : ""
    def container = task.container.toString() - "quay.io/jvhagey/phoenix:"
    """
    full_path=\$(readlink -f ${outdir})

    GRiPHin.py -d \$full_path -a $db --output ${outdir} --coverage ${coverage} ${phoenix} ${scaffolds}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
       python: \$(python --version | sed 's/Python //g')
       phoenix_base_container: ${container}
    END_VERSIONS
    """
}