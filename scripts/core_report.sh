#########################################################
# ARGS
#########################################################
output_dir=$1
project_id=$2
pipeline_results=$3
wgs_results=$4
ncbi_results=$5
subworkflow=$6

final_results=$output_dir/analysis/reports/final_report.csv
##########################################################
# Set flags
#########################################################
flag_results="N"
flag_basic="N"
flag_outbreak="N"
flag_novel="N"
flag_regional="N"
flag_time="N"

if [[ $subworkflow == "BASIC" ]]; then
    flag_results="Y"
    # flag_basic="Y"
elif [[ $subworkflow == "OUTBREAK" ]]; then
    flag_outbreak="Y"
elif [[ $subworkflow == "NOVEL" ]]; then
    flag_novel="Y"
elif [[ $subworkflow == "REGIONAL" ]]; then
    flag_regional="Y"
elif [[ $subworkflow == "TIME" ]]; then
    flag_time="Y"
else
    echo "Check report type selected: $subworkflow"
    echo "Must be BASIC OUTBREAK NOVEL REGIONAL TIME"
    exit
fi

if [[ $flag_results == "Y" ]]; then
    # read in final report; create sample list
    if [[ -f $output_dir/analysis/intermed/tmp_sampleids.txt ]]; then rm $output_dir/analysis/intermed/tmp_sampleids.txt; fi
    cat $pipeline_results | awk -F"\t" '{print $1}' | grep -v "ID"> $output_dir/analysis/intermed/tmp_sampleids.txt
    IFS=$'\n' read -d '' -r -a sample_list < $output_dir/analysis/intermed/tmp_sampleids.txt
    
    # set file
    chunk1="specimen_id,wgs_id,srr_number,wgs_date_put_on_sequencer,sequence_classification,run_id"
    chunk2="auto_qc_outcome,estimated_coverage,genome_length,assembly_ratio_(stdev),species,mlst_ccheme_1"
    chunk3="mlst_1,mlst_scheme_2,mlst_2,gamma_beta_lactam_resistance_genes,hypervirulence"
    chunk4="auto_qc_failure_reason"
    echo -e "${chunk1},${chunk2},${chunk3},${chunk4}" > $final_results 

    for id in "${sample_list[@]}"; do
        echo "--$id"
        # create final result file
        specimen_id=$id
        wgs_id=`cat $wgs_results | grep $specimen_id | awk -F"," '{print $2}'`
        srr_number=`cat $ncbi_results | grep $wgs_id | awk -F"," '{print $2}'`
        wgs_date_put_on_sequencer=`echo $project_id | cut -f3 -d"-"`
        run_id=$project_id
        
        # determine row 
        SID=$(awk -v sid=$specimen_id '{ if ($1 == sid) print NR }' $pipeline_results)
        Auto_QC_Outcome=`cat $pipeline_results | awk -F"\t" -v i=$SID 'FNR == i {print $2}'`
        Estimated_Coverage=`cat $pipeline_results | awk -F"\t" -v i=$SID 'FNR == i {print $4}'`
        Genome_Length=`cat $pipeline_results | awk -F"\t" -v i=$SID 'FNR == i {print $5}'`
        Assembly_Ratio=`cat $pipeline_results | awk -F"\t" -v i=$SID 'FNR == i {print $6}'`
        Species=`cat $pipeline_results | awk -F"\t" -v i=$SID 'FNR == i {print $14}' | sed "s/([0-9]*.[0-9]*%)//g" | sed "s/  //g"`
        MLST_Scheme_1=`cat $pipeline_results | awk -F"\t" -v i=$SID 'FNR == i {print $15}'`
        MLST_1=`cat $pipeline_results | awk -F"\t" -v i=$SID 'FNR == i {print $16}'`
        MLST_Scheme_2=`cat $pipeline_results | awk -F"\t" -v i=$SID 'FNR == i {print $17}'`
        MLST_2=`cat $pipeline_results | awk -F"\t" -v i=$SID 'FNR == i {print $18}'`
        sequence_classification=`echo "MLST<$MLST_1><$MLST_Scheme_1><$Species>"`
        GAMMA_Beta_Lactam_Resistance_Genes=`cat $pipeline_results | awk -F"\t" -v i=$SID 'FNR == i {print $19}'`
        Hypervirulence_Genes=`cat $pipeline_results | awk -F"\t" -v i=$SID 'FNR == i {print $22}'`
        Auto_QC_Failure_Reason=`cat $pipeline_results | awk -F"\t" -v i=$SID 'FNR == i {print $24}'`
        
        chunk1="$specimen_id,$wgs_id,$srr_number,$wgs_date_put_on_sequencer,\"${sequence_classification}\",$run_id"
        chunk2="$Auto_QC_Outcome,$Estimated_Coverage,$Genome_Length,$Assembly_Ratio,"${Species}",$MLST_Scheme_1"
        chunk3="\"${MLST_1}\",$MLST_Scheme_2,\"${MLST_2}\",\"${GAMMA_Beta_Lactam_Resistance_Genes}\",\"${Hypervirulence_Genes}\""
        chunk4="\"${Auto_QC_Failure_Reason}\""
        echo -e "${chunk1},${chunk2},${chunk3},${chunk4}" >> $final_results
    done
fi

if [[ $flag_basic == "Y" ]]; then
    AMRFinder/${metaid}_all_genes.tsv
    # sampletable
    ## generated from Phoenix
    sampletable="$analysis_dir/final_report.csv"

    # snpmatrix
    ## generated from CFSAN
    snpmatrix="$intermed_dir/snp_distance_matrix.tsv"
    
    # tree
    ## generated from CORETREE
    tree="$intermed_dir/core_genome.tree"

    # core stats
    ## generated from ROARY
    cgstats="$intermed_dir/core_genome_statistics.txt"
    
    # generate predictions file
    ## generated from AMRFinder/${metaid}_all_genes.tsv
    amr_reports="$intermed_dir/ar_all_genes.tsv"
    ar_predictions="$intermed_dir/ar_predictions.tsv"
    echo -e "Sample \tGene \tCoverage \tIdentity" > $ar_predictions
    awk '{print FILENAME"\t"\$0}' $amr_reports | \
    awk -F"\t" '{print \$1"\t"\$7"\t"\$17"\t" \$18}' | sed -s "s/_all_genes.tsv//g" > tmp_ar_predictions.tsv
    cat tmp_ar_predictions.tsv | grep -v "_Coverage_of_reference_sequence" >> $ar_predictions
    rm tmp_ar_predictions.tsv

    # set up reports
    arRMD="$analysis_dir/reports/ar_report_basic.Rmd"
    cp ar_report_basic.Rmd $arRMD

    # change out 
	todaysdate=$(date '+%Y-%m-%d')
    sed -i "s/REP_PROJID/$project_name/g" $arRMD
    sed -i "s~REP_OUT~$analysis_dir/reports/~g" $arRMD
    sed -i "s~REP_DATE~$todaysdate~g" $arRMD
    sed -i "s~REP_ST~$intermed_dir/final_report.csv~g" $arRMD
    sed -i "s~REP_SNP~$intermed_dir/snp_distance_matrix.tsv~g" $arRMD
    sed -i "s~REP_TREE~$intermed_dir/core_genome.tree~g" $arRMD
    sed -i "s~REP_CORE~$intermed_dir/core_genome_statistics.txt~g" $arRMD
    sed -i "s~REP_AR~$intermed_dir/ar_predictions.tsv~g" $arRMD
fi