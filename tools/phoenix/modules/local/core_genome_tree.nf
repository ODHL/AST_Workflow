process TREE {
  tag "CORE TREE"
  label 'process_high'
  container 'staphb/iqtree:1.6.7'
  
  input:
  path(aln)

  output:
  path('*core_genome.tree')           , emit: genome_tree

  script:
  def args = task.ext.args ?: ''
  """
  numGenomes=`grep -v '>' ${aln} | sed '/^\$/d' | wc -l`
  if [ \$numGenomes -gt 3 ]; then
    iqtree -nt AUTO -s ${aln} -keep-ident -m $args -bb 1000
    mv core_gene_alignment.aln.contree core_genome.tree
  else
    echo "There is not enough points at 80% conformity" > core_genome.tree
  fi
  """
}