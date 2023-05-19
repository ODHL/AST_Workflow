// https://sanger-pathogens.github.io/Roary/

//https://github.com/sanger-pathogens/Roary/blob/master/contrib/roary_plots/roary_plots.py
// https://sanger-pathogens.github.io/Roary/
process ROARY_PLOTS {
    tag "ROARY_PLOTS"
    label 'process_low'

    input:
    file(tree)
    file(gene_presence_absence)

    output:
    path('*pangenome_frequency*')      , emit: freq
    path('*pangenome_matrix*')         , emit: matrix
    path('*pangenome_pie**')           , emit: pie

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    python3 -m pip install -U matplotlib seaborn
    roary_plots.py ${tree} ${gene_presence_absence}
    """
}