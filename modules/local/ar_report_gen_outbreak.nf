process AR_REPORT {
    tag "AR_REPORT"
    label 'process_low'
    container 'quay.io/wslh-bioinformatics/ar-report:latest'

    input:
    path(final_report)              // Phoenix_Output_Report.tsv
    path(amr_reports)               // AMRFinder/${metaid}_all_genes.tsv
    file(ar_config)                 // ar_report_config.yaml
    path(snpmatrix)                 // CFSAN.out.distmatrix
    path(tree)                      // TREE.out.genome_tree
    path(core_genome)               // ROARY.out.core_stats

    output:
    path "*.ar-report.html"                                      , emit: ar_html

    script:
    """
    # create ar_predictions
    echo -e "Sample \tGene \tCoverage \tIdentity" > ar_predictions.tsv
    awk '{print FILENAME"\t"\$0}' $amr_reports | \
    awk -F"\t" '{print \$1"\t"\$7"\t"\$17"\t" \$18}' | sed -s "s/_all_genes.tsv//g" > ar_predictions_tmp.tsv
    cat ar_predictions_tmp.tsv | grep -v "_Coverage_of_reference_sequence" >> ar_predictions.tsv

    # Prep sample manifest
    tail -n +2 $final_report > report.tsv
    sed -i "s/,/;/g" report.tsv

    # final manifest
    echo -e ""Lab ID"",""WGS ID"",""Date Collected"",""Organism"",""Specimen Source"",""Resistance Genes"",""Comments"" > ar_report_manifest.csv
    awk -F"\t" '{print \$1",,,"\$9",,"\$18","}' report.tsv >> ar_report_manifest.csv

    # Set date
    today=`date +%Y%m%d`

    Rscript /home/ubuntu/workflows/AST_Workflow/bin/render_report.R \\
    \$today \\
    'Dr. Samantha Chill' \\
    ar_report_manifest.csv \\
    ${ar_config} \\
    $PWD/ \\
    --snpmatrix ${snpmatrix} \\
    --tree $PWD/${tree} \\
    --cgstats ${core_genome} \\
    --artable ar_predictions.tsv \\
    --freq $PWD/${pangenome_frequency} \\
    --matrix $PWD/${pangenome_matrix} \\
    --pie $PWD/${pangenome_pie}
    """
}