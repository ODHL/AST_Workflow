#########################################################
# ARGS
#########################################################
output_dir=$1
project_name_full=$2
pipeline_results=$3
wgs_results=$4
subworkflow=$5
pipeline_config=$6
pipeline_log=$7

##########################################################
# Eval, source
#########################################################
source $(dirname "$0")/core_functions.sh
eval $(parse_yaml ${pipeline_config} "config_")

#########################################################
# Set dirs, files, args
#########################################################
log_dir=$output_dir/logs
analysis_dir=$output_dir/analysis
intermed_dir=$analysis_dir/intermed
report_dir=$analysis_dir/reports

sample_ids=$output_dir/logs/manifests/sample_ids.txt
project_name=$(echo $project_name_full | cut -f1 -d "_" | cut -f1 -d " ")

final_results=$report_dir/final_report.csv
merged_prediction="$intermed_dir/ar_predictions.tsv"
merged_snp="$intermed_dir/snp_distance_matrix.tsv"
merged_tree="$intermed_dir/core_genome.tree"
merged_cgstats="$intermed_dir/core_genome_statistics.txt"

# set cmd
analysis_cmd=$config_analysis_cmd
##########################################################
# Set flags
#########################################################
flag_report="N"
flag_basic="N"
flag_outbreak="N"

if [[ $subworkflow == "REPORT" ]]; then
    flag_report="Y"
elif [[ $subworkflow == "BASIC" ]]; then
    flag_basic="Y"
    analysis_cmd_trailing=$config_basic_report_cmd_trailing
elif [[ $subworkflow == "OUTBREAK" ]]; then
    flag_outbreak="Y"
    analysis_cmd_trailing=$config_outbreak_report_cmd_trailing
else
    echo "Check report type selected: $subworkflow"
    echo "Must be REPORT BASIC OUTBREAK"
    exit
fi

##########################################################
# update reports
#########################################################
todaysdate=$(date '+%Y-%m-%d')
files_save=(ar_report_outbreak.Rmd ar_report_basic.Rmd)
for f in "${files_save[@]}"; do 
    cp "tools/phoenix/bin/$f" "$analysis_dir/reports/"
    sed -i "s/REP_PROJID/$project_name/g" $analysis_dir/reports/$f
    sed -i "s/REP_OB/$project_name/g" $analysis_dir/reports/$f
    sed -i "s~REP_DATE~$todaysdate~g" $analysis_dir/reports/$f
done

##########################################################
# Run analysis
#########################################################    
if [[ $flag_report == "Y" ]]; then
    message_cmd_log "------------------------------------------------------------------------"
	message_cmd_log "--BASIC REPORT to NF"
	message_cmd_log "------------------------------------------------------------------------"
        
    # read in final report; create sample list
    IFS=$'\n' read -d '' -r -a sample_list < $sample_ids
    
    # set file
    chunk1="specimen_id,wgs_id,srr_id,wgs_date_put_on_sequencer,sequence_classification,run_id"
    chunk2="auto_qc_outcome,estimated_coverage,genome_length,species,mlst_scheme_1"
    chunk3="mlst_1,mlst_scheme_2,mlst_2,gamma_beta_lactam_resistance_genes"
    chunk4="auto_qc_failure_reason,lab_results,samn_id"
    echo -e "${chunk1},${chunk2},${chunk3},${chunk4}" > $final_results 
    
    # generate predictions file
    echo -e "Sample \tGene \tCoverage \tIdentity" > $merged_prediction

    # create final result file    
    for sample_id in "${sample_list[@]}"; do
        sample_id=$(clean_file_names $sample_id)
        cleanid=`echo $sample_id | cut -f1 -d"-"`
        echo "--$cleanid"

        # check WGS ID, if available
        if [[ $sample_id != *"SRR"* ]]; then
            wgs_id=`cat $wgs_results | grep $sample_id | awk -F"," '{print $2}' | sort | uniq`
            srr_number=`cat srr_db/srr_db_master.csv | grep $wgs_id | awk -F"," '{print $1}'`
            samn_number=`cat srr_db/srr_db_master.csv | grep $wgs_id | awk -F"," '{print $3}'`
        else
            wgs_id="NO_ID"
            srr_number="$sample_id"
            samn_number="NO_ID"
        fi
        
        # set seq info
        wgs_date_put_on_sequencer=`echo $project_name | cut -f3 -d"-"`
        run_id=$project_name
        
        # determine row 
        SID=$(awk -F";" -v sid=$sample_id '{ if ($1 == sid) print NR }' $pipeline_results)
        SID=`echo $SID | cut -d" " -f1`

        # pull metadata
        Auto_QC_Outcome=`cat $pipeline_results | awk -F";" -v i=$SID 'FNR == i {print $2}'`
        Estimated_Coverage=`cat $pipeline_results | awk -F";" -v i=$SID 'FNR == i {print $4}'`
        Genome_Length=`cat $pipeline_results | awk -F";" -v i=$SID 'FNR == i {print $5}'`
        Auto_QC_Failure_Reason=`cat $pipeline_results | awk -F";" -v i=$SID 'FNR == i {print $24}'`

        # if samples fail due to seq (low reads), adjust
        if [[ $Auto_QC_Outcome == "" ]]; then Auto_QC_Outcome="SeqFAIL"; Auto_QC_Failure_Reason="sequencing_failure"; fi

        # recap    
        echo "----$Auto_QC_Outcome"    
        echo "----$wgs_id"
        echo "----$srr_number"
        echo "----$samn_number"

        # get MLST;u $9}' | sed "s/([0-9]*.[0-9]*%)//g" | sed "s/  //g"`
        MLST_1=`cat $pipeline_results | awk -F";" -v i=$SID 'FNR == i {print $16}'| cut -f1 -d","`
        MLST_Scheme_1=`cat $pipeline_results | sort | uniq | awk -F";" -v i=$SID 'FNR == i {print $15}'`
        MLST_2=`cat $pipeline_results | sort | uniq | awk -F";" -v i=$SID 'FNR == i {print $18}'| cut -f1 -d","`
        MLST_Scheme_2=`cat $pipeline_results | awk -F";" -v i=$SID 'FNR == i {print $17}'`
        sequence_classification=`cat $pipeline_results | awk -F";" -v i=$SID 'FNR == i {print $25}'`

        # set genes
        GAMMA_Beta_Lactam_Resistance_Genes=`cat $pipeline_results | awk -F";" -v i=$SID 'FNR == i {print $19}'`
        
        # set genes
        LabValidation=`cat $pipeline_results | awk -F";" -v i=$SID 'FNR == i {print $26}'`

        # prepare chunks
        chunk1="$sample_id,$wgs_id,$srr_number,$wgs_date_put_on_sequencer,\"${sequence_classification}\",$run_id"
        chunk2="$Auto_QC_Outcome,$Estimated_Coverage,$Genome_Length,"${Species}",$MLST_Scheme_1"
        chunk3="\"${MLST_1}\",$MLST_Scheme_2,\"${MLST_2}\",\"${GAMMA_Beta_Lactam_Resistance_Genes}\""
        chunk4="\"${Auto_QC_Failure_Reason}\",\"${LabValidation}\",\"${samn_number}\""
        echo -e "${chunk1},${chunk2},${chunk3},${chunk4}" >> $final_results
    	
        # create all genes output file
		if [[ $Auto_QC_Outcome == "PASS" ]]; then
            cat $output_dir/tmp/amr/${sample_id}_all_genes.tsv | awk -F"\t" '{print $2"\t"$6"\t"$16"\t"$17}' | sed -s "s/_all_genes.tsv//g" | grep -v "_Coverage_of_reference_sequence">> $merged_prediction
        fi
    done

    echo $final_results
fi

if [[ $flag_basic == "Y" ]]; then

    # run multiQC
	if [[ ! -f $qc_report ]]; then
        runMULTIQC
    fi
    if [[ -f $qc_report ]]; then
        rm -rf $output_dir/tmp/rawdata/fastq
    fi
    
    # create report
    source ~/.bashrc
    samplesheet=$log_dir/manifests/samplesheet_gff.csv
	pipeline_full_cmd="$analysis_cmd $analysis_cmd_trailing --input $samplesheet --outdir $output_dir/ --projectID $project_name -with-conda"
    echo $pipeline_full_cmd
    $pipeline_full_cmd

    if [[ -f $output_dir/basic/basic.html ]]; then
        cp $output_dir/basic/basic.html $output_dir/analysis/reports/
        rm -rf $output_dir/basic $output_dir/pipeline_info
        echo "** PIPELINE REPORT SUCCESSFUL **"
    else
        echo "** PIPELINE REPORT FAILED **"
    fi
fi

if [[ $flag_outbreak == "Y" ]]; then    
    message_cmd_log "------------------------------------------------------------------------"
	message_cmd_log "--OUTBREAK REPORT to NF"
	message_cmd_log "------------------------------------------------------------------------"
    
    # read in final report; create sample list
    IFS=$'\n' read -d '' -r -a sample_list < $sample_ids

    # generate predictions file
    echo -e "Sample \tGene \tCoverage \tIdentity" > $merged_prediction

    # create final result file    
    for sample_id in "${sample_list[@]}"; do
        cleanid=`echo $sample_id | cut -f1 -d"-"`
        cat $output_dir/tmp/amr/${cleanid}*all_genes.tsv | awk -F"\t" '{print $2"\t"$6"\t"$16"\t"$17}' | sed -s "s/_all_genes.tsv//g" | grep -v "_Coverage_of_reference_sequence" >> $merged_prediction
	done

    # create report
    samplesheet=$log_dir/manifests/samplesheet_gff.csv
	pipeline_full_cmd="$analysis_cmd $analysis_cmd_trailing --input $samplesheet --outdir $output_dir/ --projectID $project_name -with-conda"
    echo $pipeline_full_cmd
    $pipeline_full_cmd

    if [[ -f $output_dir/outbreak/outbreak.html ]]; then
        cp $output_dir/outbreak/outbreak.html $output_dir/analysis/reports/
        rm -rf $output_dir/outbreak $output_dir/pipeline_info
        echo "** PIPELINE REPORT SUCCESSFUL **"
    else
        echo "** PIPELINE REPORT FAILED **"
    fi
fi