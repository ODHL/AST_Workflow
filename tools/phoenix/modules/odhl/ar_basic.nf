process BASIC_REPORT {
  tag "BASIC REP"
  label 'process_high'

  conda 'assets/reports.yaml'
  
  input:
    val(projectID)
    path(Rscript)
    path(logoFile)
    path(ar_predictions)
    path(core_stats)
    path(snp_dist)
    path(core_tree)
    path(ar_config)
    path(metadata)
    path(pipe_report)

  output:
    path('*.html')           , emit: report

  script:
  """
  Rscript -e 'rmarkdown::render("${Rscript}", output_file="basic.html", output_dir = getwd())'
  """
}
