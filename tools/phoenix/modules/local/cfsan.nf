process CFSAN {
  tag "CFSAN"
  label 'process_high'
  container 'staphb/cfsan-snp-pipeline:2.2.1'
  
  input:
  path(inputdir)
  path(db)
  path(config)

  output:
  path('*snp_distance_matrix.tsv')            , emit: distmatrix
  path('*snpma.fasta')                        , emit: snpma

  // cfsan requires each sample to be in a subfolder
  script:
  """

  cfsan_snp_pipeline run ${db} -c ${config} -o . -s $inputdir
  """
}