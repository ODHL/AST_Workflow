#########################################################
# ARGS
#########################################################
output_dir=$1
project_id=$2
pipeline_results=$3
wgs_results=$4
ncbi_results=$5
subworkflow=$6
pipeline_config=$7

##########################################################
# Eval, source
#########################################################
source $(dirname "$0")/core_functions.sh
eval $(parse_yaml ${pipeline_config} "config_")

#########################################################
# Set dirs, files, args
#########################################################
final_results=$output_dir/analysis/reports/final_report.csv
analysis_dir=$output_dir/analysis
report_dir=$analysis_dir/reports
intermed_dir=$analysis_dir/intermed
log_dir=$output_dir/logs
ncbi_dir=$output_dir/ncbi
multiqc_config=$log_dir/config/config_multiqc.yaml
fastqc_dir=$analysis_dir/qc/data
qcreport_dir=$analysis_dir/qc
multiqc_log=$log_dir/pipeline_log.txt
merged_amr=$intermed_dir/ar_all_genes.tsv
sample_ids=$output_dir/logs/manifests/sample_ids.txt

##########################################################
# Set flags
#########################################################
flag_basic="N"
flag_outbreak="N"
flag_novel="N"
flag_regional="N"
flag_time="N"

if [[ $subworkflow == "BASIC" ]]; then
    flag_basic="Y"
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

##########################################################
# Run analysis
#########################################################
if [[ $flag_basic == "Y" ]]; then
    echo "--creating basic report"
    # read in final report; create sample list
    IFS=$'\n' read -d '' -r -a sample_list < $sample_ids
    
    # set file
    chunk1="specimen_id,wgs_id,srr_id,wgs_date_put_on_sequencer,sequence_classification,run_id"
    chunk2="auto_qc_outcome,estimated_coverage,genome_length,species,mlst_scheme_1"
    chunk3="mlst_1,mlst_scheme_2,mlst_2,gamma_beta_lactam_resistance_genes"
    chunk4="auto_qc_failure_reason"
    echo -e "${chunk1},${chunk2},${chunk3},${chunk4}" > $final_results 
    
    # create final result file    
    for id in "${sample_list[@]}"; do
        # set id
        specimen_id=$id
        
        # check WGS ID, if available
        if [[ -f $wgs_results ]]; then 
            wgs_id=`cat $wgs_results | grep $specimen_id | awk -F"," '{print $2}'`
        else
            wgs_id="NO_ID"
        fi

        # check NCBI, if available
        if [[ -f $ncbi_results ]]; then
            srr_number=`cat $ncbi_results | grep $wgs_id | awk -F"," '{print $2}'`
        else
            srr_number="NO_ID"
        fi

        # set seq info
        wgs_date_put_on_sequencer=`echo $project_id | cut -f3 -d"-"`
        run_id=$project_id
        
        # determine row 
        SID=$(awk -F";" -v sid=$specimen_id '{ if ($1 == sid) print NR }' $pipeline_results)

        # pull metadata
        Auto_QC_Outcome=`cat $pipeline_results | awk -F";" -v i=$SID 'FNR == i {print $2}'`
        Estimated_Coverage=`cat $pipeline_results | awk -F";" -v i=$SID 'FNR == i {print $4}'`
        Genome_Length=`cat $pipeline_results | awk -F";" -v i=$SID 'FNR == i {print $5}'`
        Auto_QC_Failure_Reason=`cat $pipeline_results | awk -F";" -v i=$SID 'FNR == i {print $24}'`
        
        # set taxonomy
        Species=`cat $pipeline_results | awk -F";" -v i=$SID 'FNR == i {print $14}' | sed "s/([0-9]*.[0-9]*%)//g" | sed "s/  //g"`
        MLST_Scheme_1=`cat $pipeline_results | awk -F";" -v i=$SID 'FNR == i {print $15}'`
        MLST_1=`cat $pipeline_results | awk -F";" -v i=$SID 'FNR == i {print $16}'`
        MLST_Scheme_2=`cat $pipeline_results | awk -F";" -v i=$SID 'FNR == i {print $17}'`
        MLST_2=`cat $pipeline_results | awk -F";" -v i=$SID 'FNR == i {print $18}'`
        sequence_classification=`echo "MLST_${MLST_1}_${MLST_Scheme_1}_${Species}"`
        
        # set genes
        GAMMA_Beta_Lactam_Resistance_Genes=`cat $pipeline_results | awk -F";" -v i=$SID 'FNR == i {print $19}'`
        
        # prepare chunks
        chunk1="$specimen_id,$wgs_id,$srr_number,$wgs_date_put_on_sequencer,\"${sequence_classification}\",$run_id"
        chunk2="$Auto_QC_Outcome,$Estimated_Coverage,$Genome_Length,"${Species}",$MLST_Scheme_1"
        chunk3="\"${MLST_1}\",$MLST_Scheme_2,\"${MLST_2}\",\"${GAMMA_Beta_Lactam_Resistance_Genes}\""
        chunk4="\"${Auto_QC_Failure_Reason}\""
        echo -e "${chunk1},${chunk2},${chunk3},${chunk4}" >> $final_results
    	
        # create all genes output file
		cat $intermed_dir/val/${id}_all_genes.tsv >> $merged_amr
	done

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
    ar_predictions="$intermed_dir/ar_predictions.tsv"
    echo -e "Sample \tGene \tCoverage \tIdentity" > $ar_predictions
    for f in $intermed_dir/val/*_all_genes.tsv; do
        awk -F"\t" '{print $2"\t"$6"\t"$16"\t"$17}' $f | sed -s "s/_all_genes.tsv//g" | grep -v "_Coverage_of_reference_sequence">> $ar_predictions
    done

    # set up reports
    arRMD="$analysis_dir/reports/ar_report_basic.Rmd"
    cp scripts/ar_report_basic.Rmd $arRMD
    cp assets/odh_logo_231222.jpg $analysis_dir/reports

    # change out
    micropath="L://Micro/WGS/AR WGS/projects/$project_id"
    intermedpath="$micropath/analysis/intermed"
    reportpath="$micropath/analysis/reports"
    arCONFIG="$micropath/logs/config/config_ar_report.yaml"
	todaysdate=$(date '+%Y-%m-%d')
    sed -i "s~REP_CONFIG~$arCONFIG~g" $arRMD
    sed -i "s/REP_PROJID/$project_id/g" $arRMD
    sed -i "s~REP_OUT~$micropath/reports/~g" $arRMD
    sed -i "s~REP_DATE~$todaysdate~g" $arRMD
    sed -i "s~REP_ST~$reportpath/final_report.csv~g" $arRMD
    sed -i "s~REP_SNP~$intermedpath/snp_distance_matrix.tsv~g" $arRMD
    sed -i "s~REP_TREE~$intermedpath/core_genome.tree~g" $arRMD
    sed -i "s~REP_CORE~$intermedpath/core_genome_statistics.txt~g" $arRMD
    sed -i "s~REP_AR~$intermedpath/ar_predictions.tsv~g" $arRMD
    sed -i "s~REP_LOGO~$config_logo_file~g" $arRMD

    # zip fastq
    batch_count=`ls $ncbi_dir/*/manifest_batch_* | wc -l`
	batch_min=1
	
	for (( batch_id=$batch_min; batch_id<=$batch_count; batch_id++ )); do
		batch_dir="$ncbi_dir/batch_0$batch_id"
        cd $ncbi_dir
        if [[ ! -f batch_0$batch_id.tar.gz ]]; then tar -zcvf batch_0$batch_id.tar.gz $batch_dir/; fi
        #rm -rf $batch_dir
        
        # undo 
        # mkdir test; tar -zxf batch_01.tar.gz --directory test
    done

    # run multiQC
	## -d -dd 1 adds dir name to sample name
	if [[ ! -f $qcreport_dir/multiqc_report.html ]]; then
        multiqc -f -v \
        -c $multiqc_config \
        $fastqc_dir \
        -o $qcreport_dir 2>&1 | tee -a $multiqc_log
    fi

    if [[ -f $qcreport_dir/multiqc_report.html ]] && [[ ! -f $fastqc_dir.tar.gz ]]; then
        cp $qcreport_dir/multiqc_report.html $report_dir
        tar -zcvf $fastqc_dir.tar.gz $fastqc_dir/
        rm -rf $fastqc_dir
    fi

    head $final_results
fi

if [[ $flag_outbreak == "Y" ]]; then
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
    ar_predictions="$intermed_dir/ar_predictions.tsv"
    echo -e "Sample \tGene \tCoverage \tIdentity" > $ar_predictions
    for f in $intermed_dir/val/*_all_genes.tsv; do
        awk -F"\t" '{print $2"\t"$6"\t"$16"\t"$17}' $f | sed -s "s/_all_genes.tsv//g" | grep -v "_Coverage_of_reference_sequence">> $ar_predictions
    done

    # set up reports
    arRMD="$analysis_dir/reports/ar_report_outbreak.Rmd"
    cp scripts/ar_report_outbreak.Rmd $arRMD
    cp $config_logo_file $analysis_dir/reports

    # change out
    micropath="L://Micro/WGS/AR WGS/projects/$project_id"
    intermedpath="$micropath/analysis/intermed"
    reportpath="$micropath/analysis/reports"
    arCONFIG="$micropath/logs/config/config_ar_report.yaml"
	todaysdate=$(date '+%Y-%m-%d')
    sed -i "s~REP_CONFIG~$arCONFIG~g" $arRMD
    sed -i "s/REP_PROJID/$project_id/g" $arRMD
    sed -i "s~REP_OUT~$micropath/reports/~g" $arRMD
    sed -i "s~REP_DATE~$todaysdate~g" $arRMD
    sed -i "s~REP_ST~$reportpath/final_report.csv~g" $arRMD
    sed -i "s~REP_SNP~$intermedpath/snp_distance_matrix.tsv~g" $arRMD
    sed -i "s~REP_TREE~$intermedpath/core_genome.tree~g" $arRMD
    sed -i "s~REP_CORE~$intermedpath/core_genome_statistics.txt~g" $arRMD
    sed -i "s~REP_AR~$intermedpath/ar_predictions.tsv~g" $arRMD
    sed -i "s~REP_LOGO~$config_logo_file~g" $arRMD

    # zip fastq
    cd $intermed_dir
    for f in $intermed_dir/tree/input_dir/*/*; do
        if [[ ! -f $f.gz ]]; then 
            rm -rf $f
        fi
    done
    tar -zcvf tree.tar.gz $intermed_dir/
fi