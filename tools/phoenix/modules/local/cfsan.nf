process CFSAN {
  tag "CFSAN"
  label 'process_high'
  container 'staphb/cfsan-snp-pipeline:2.2.1'
  
  input:
  file(reads)
  path(db)
  path(config)

  output:
  path('*snp_distance_matrix.tsv')           , emit: distmatrix
  path('*snpma.fasta')           , emit: snpma

  // cfsan requires each sample to be in a subfolder
  script:
  """
  for rid in ${reads}; do
    prefix=`echo \$rid | cut -f1 -d"_"`
    read=`echo \$rid | cut -f2 -d"_" | cut -f1 -d"."`
    mkdir -p input_reads/\$prefix
    mv \$rid input_reads/\$prefix/\${prefix}_\${read}.fastq.gz
  done

  cfsan_snp_pipeline run ${db} -c ${config} -o . -s input_reads
  """
}