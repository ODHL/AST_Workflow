process samtools_stats {
  tag        "${meta.id}"
  label      "process_single"
  container  'staphb/samtools:1.19'
  
  input:
    tuple val(sample), file(bam)

  output:
    path "samtools_stats/${meta.id}.stats.txt", emit: samtools_stats_files
    path "samtools_coverage/${meta.id}.cov.{txt,hist}", emit: files
    path "samtools_coverage/${meta.id}.cov.txt", emit: samtools_coverage
    path "samtools_flagstat/${meta.id}.flagstat.txt", emit: samtools_flagstat_files
    path "samtools_depth/${meta.id}.depth.txt", emit: file
    tuple val(sample), file("samtools_ampliconstats/${meta.id}_ampliconstats.txt"), emit: samtools_ampliconstats_files

  shell:
    def args_stats   = task.ext.args   ?: "${params.samtools_stats_options}"
    def args_cov   = task.ext.args   ?: "${params.samtools_coverage_options}"
    def args_flag   = task.ext.args   ?: "${params.samtools_flagstat_options}"
    def args_depth   = task.ext.args   ?: "${params.samtools_depth_options}"
    def args_amp   = task.ext.args   ?: "${params.samtools_ampliconstats_options}"
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p samtools_stats logs/${task.process}

    samtools stats ${args_stats} ${bam} > samtools_stats/${prefix}.stats.txt
    samtools coverage ${args_cov} ${bam} -m -o samtools_coverage/${prefix}.cov.hist | tee -a \$log
    samtools coverage ${args_cov} ${bam} | awk -v sample=${prefix} '{print sample "\\t" \$0 }' | sed '0,/${prefix}/s//sample/' > samtools_coverage/${prefix}.cov.txt  | tee -a \$log
    samtools flagstat ${args_flag} ${bam} | tee samtools_flagstat/${prefix}.flagstat.txt
    samtools depth ${args_depth} ${bam} > samtools_depth/${prefix}.depth.txt
    samtools ampliconstats ${args_amp} ${primer_bed} ${bam} > samtools_ampliconstats/${prefix}_ampliconstats.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
      samtools: \$(samtools --version | head -n 1 | awk '{print \$NF}')
      container: ${task.container}
    END_VERSIONS
    """
}