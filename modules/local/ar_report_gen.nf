process AR_REPORT {
    tag "AR_REPORT"
    label 'process_low'
    container 'quay.io/wslh-bioinformatics/ar-report:latest'

    input:
    path(final_report)              // Analysis_Output_Report.tsv
    path(amr_reports)               // AMRFinder/${metaid}_all_genes.tsv
    file(ar_config)                 //ar_report_config.yaml
    path(snpmatrix)                 // CFSAN.out.distmatrix
    path(tree)                      // TREE.out.genome_tree
    path(core_genome)               // ROARY.out.core_stats
    path(pangenome_frequency)
    path(pangenome_matrix)
    path(pangenome_pie)

    output:
    path "*.ar-report.html"                                      , optional:true,        emit: ar_html
    path "*.ar-report.docx"                                      , optional:true,        emit: ar_docx

    script:
    """
    # create ar_predictions
    echo -e "Sample \tGene \tCoverage \tIdentity" > ar_predictions.tsv
    awk '{print FILENAME"\t"\$0}' 2022020665_all_genes.tsv 2022019541_all_genes.tsv 2021015907_all_genes.tsv 2022020725_all_genes.tsv | \
    awk -F"\t" '{print \$1"\t"\$7"\t"\$17"\t" \$18}' | sed -s "s/_all_genes.tsv//g" > ar_predictions_tmp.tsv
    cat ar_predictions_tmp.tsv | grep -v "_Coverage_of_reference_sequence" >> ar_predictions.tsv

    # Create sample manifest
    echo -e "\"Lab ID\"","\"Isolate Collection Date\"","\"Local ID\"","\"Species ID\"","\"Specimen Source\"","\"MLST\"","\"Resistance Genes\"","\"Comments\"","\"Tree Group\"" > ar_report_manifest.csv
    tail -n +2 Phoenix_Output_Report.tsv > report.tsv
    awk -F" " '{print \$1",,"\$1","\$9",,"\$14","\$18",,"}' report.tsv >> ar_report_manifest.csv

    # Set date
    today=`date +%Y%m%d`

    Rscript /home/ubuntu/.nextflow/assets/ODHL/AST/bin/render_report.R \\
    \$today \\
    'Dr. Samantha Chill' \\
    ar_report_manifest.txt \\
    ${ar_config} \\
    $PWD/ \\
    --snpmatrix $PWD/${snpmatrix} \\
    --tree $PWD/${tree} \\
    --cgstats $PWD/${core_genome} \\
    --artable $PWD/ar_predictions.tsv \\
    --freq $PWD/${pangenome_frequency} \\
    --matrix $PWD/${pangenome_matrix} \\
    --pie $PWD/${pangenome_pie}
    """
}
