process OUTBREAK_REPORT {
  tag "OUTBREAK REP"
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
  
  # Run script
  Rscript $Rscript

  library(rmarkdown)
  
  # Function to knit R Markdown file
  knit_report <- function(report_file) {
    render(report_file, output_format = 'flexdashboard::flex_dashboard')
    }
    
    # Render R Markdown report
    knit_report('${Rscript}')

  """
}
