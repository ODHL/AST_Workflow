//https://sanger-pathogens.github.io/Roary/
process ROARY {
    tag "ROARY"
    label 'process_high'
    container 'staphb/roary:3.12.0'

    numGenomes = 0
  
    input:
    file(gff)

    output:
    path('*.aln')                                 , emit: aln
    path('*core_genome_statistics.txt')           , emit: core_stats
    path('*gene_presence_absence.csv')            , emit: present_absence

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    roary -e $args -p $task.cpus -i 90 ${gff}
    mv summary_statistics.txt core_genome_statistics.txt
    """
}