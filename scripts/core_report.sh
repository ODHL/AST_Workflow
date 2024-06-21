#########################################################
# ARGS
#########################################################
output_dir=$1
project_name_full=$2
pipeline_results=$3
wgs_results=$4
ncbi_results=$5
subworkflow=$6
pipeline_config=$7
pipeline_log=$8
OBID=$9

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

ncbi_dir=$output_dir/tmp/ncbi
fastqc_dir=$output_dir/tmp/qc/data
qcreport_dir=$output_dir/tmp/qc

sample_ids=$output_dir/logs/manifests/sample_ids.txt

merged_amr=$intermed_dir/core_amr_genes.tsv
merged_tree=$intermed_dir/core_genome.tree
merged_roary=$intermed_dir/core_genome_statistics.txt
merged_snp=$intermed_dir/snp_distance_matrix.tsv

multiqc_config=$log_dir/config/config_multiqc.yaml
multiqc_log=$log_dir/pipeline_log.txt
final_results=$report_dir/final_report.csv
merged_prediction="$intermed_dir/ar_predictions.tsv"
merged_snp="$intermed_dir/snp_distance_matrix.tsv"
merged_tree="$intermed_dir/core_genome.tree"
merged_cgstats="$intermed_dir/core_genome_statistics.txt"

project_name=$(echo $project_name_full | cut -f1 -d "_" | cut -f1 -d " ")
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
	message_cmd_log "------------------------------------------------------------------------"
	message_cmd_log "--BASIC REPORT"
	message_cmd_log "------------------------------------------------------------------------"
    
    # read in final report; create sample list
    IFS=$'\n' read -d '' -r -a sample_list < $sample_ids
    
    # set file
    chunk1="specimen_id,wgs_id,srr_id,wgs_date_put_on_sequencer,sequence_classification,run_id"
    chunk2="auto_qc_outcome,estimated_coverage,genome_length,species,mlst_scheme_1"
    chunk3="mlst_1,mlst_scheme_2,mlst_2,gamma_beta_lactam_resistance_genes"
    chunk4="auto_qc_failure_reason,lab_results"
    echo -e "${chunk1},${chunk2},${chunk3},${chunk4}" > $final_results 
    
    # generate predictions file
    echo -e "Sample \tGene \tCoverage \tIdentity" > $merged_prediction

    # create final result file    
    for sample_id in "${sample_list[@]}"; do
        sample_id=$(clean_file_names $sample_id)
        cleanid=`echo $sample_id | cut -f1 -d"-"`
        echo $cleanid
        
        # check WGS ID, if available
        if [[ -f $wgs_results ]]; then 
            wgs_id=`cat $wgs_results | grep $sample_id | awk -F"," '{print $2}'`
        else
            # outbreak samples will not have WGS run individually - pull projects that ID's were created
            wgs_id=`cat wgs_db/wgs_db_master.csv | grep $cleanid | awk -F"," '{print $1}'`
            if [[ $wgs_id == "" ]]; then wgs_id="NO_ID"; fi
        fi

        # check NCBI, if available
        if [[ $wgs_id != "NO_ID" ]]; then 
            srr_number=`cat srr_db/srr_db_master.csv | grep $wgs_id | awk -F"," '{print $1}'`
        else
            srr_number="NO_ID"
        fi
        if [[ $srr_number == "" ]]; then srr_number="NO_ID"; fi
        echo "----$srr_number"
        
        # set seq info
        wgs_date_put_on_sequencer=`echo $project_name | cut -f3 -d"-"`
        run_id=$project_name
        
        # determine row 
        SID=$(awk -F";" -v sid=$sample_id '{ if ($1 == sid) print NR }' $pipeline_results)

        # pull metadata
        Auto_QC_Outcome=`cat $pipeline_results | awk -F";" -v i=$SID 'FNR == i {print $2}'`
        Estimated_Coverage=`cat $pipeline_results | awk -F";" -v i=$SID 'FNR == i {print $4}'`
        Genome_Length=`cat $pipeline_results | awk -F";" -v i=$SID 'FNR == i {print $5}'`
        Auto_QC_Failure_Reason=`cat $pipeline_results | awk -F";" -v i=$SID 'FNR == i {print $24}'`
        
        # get MLST
        Species=`cat $pipeline_results | awk -F";" -v i=$SID 'FNR == i {print $9}' | sed "s/([0-9]*.[0-9]*%)//g" | sed "s/  //g"`
        MLST_1=`cat $pipeline_results | awk -F";" -v i=$SID 'FNR == i {print $16}'| cut -f1 -d","`
        MLST_Scheme_1=`cat $pipeline_results | awk -F";" -v i=$SID 'FNR == i {print $15}'`
        MLST_2=`cat $pipeline_results | awk -F";" -v i=$SID 'FNR == i {print $18}'| cut -f1 -d","`
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
        chunk4="\"${Auto_QC_Failure_Reason}\",\"${LabValidation}\""
        echo -e "${chunk1},${chunk2},${chunk3},${chunk4}" >> $final_results
    	
        # create all genes output file
		cat $output_dir/tmp/amr/${sample_id}_all_genes.tsv | awk -F"\t" '{print $2"\t"$6"\t"$16"\t"$17}' $f | sed -s "s/_all_genes.tsv//g" | grep -v "_Coverage_of_reference_sequence">> $merged_prediction
	done
    
    # set up reports
    arRMD="$analysis_dir/reports/ar_report_basic.Rmd"
    cp scripts/ar_report_basic.Rmd $arRMD
    cp assets/$config_logo_file $analysis_dir/reports

    # prepare report
    micropath="L://Micro/WGS/AR WGS/projects/$project_name"
    prepREPORT "$micropath"

    # run multiQC
	runMULTIQC

    if [[ -f $qc_report ]] && [[ ! -f $output_dir/fastq.tar.gz ]]; then
        tar -zcvf $output_dir/fastq.tar.gz $output_dir/tmp/rawdata/fastq
    fi

    head $final_results
fi

if [[ $flag_outbreak == "Y" ]]; then    
    message_cmd_log "------------------------------------------------------------------------"
	message_cmd_log "--OUTBREAK REPORT"
	message_cmd_log "------------------------------------------------------------------------"
    
    # read in final report; create sample list
    IFS=$'\n' read -d '' -r -a sample_list < $sample_ids

    # generate predictions file
    echo -e "Sample \tGene \tCoverage \tIdentity" > $merged_prediction

    # create final result file    
    for sample_id in "${sample_list[@]}"; do
		check=`cat $pipeline_results | grep $sample_id | awk -F";" '{print $2}'`
        cat $output_dir/tmp/amr/${cleanid}*all_genes.tsv | awk -F"\t" '{print $2"\t"$6"\t"$16"\t"$17}' $f | sed -s "s/_all_genes.tsv//g" | grep -v "_Coverage_of_reference_sequence">> $merged_prediction
	done

    # set up reports
    arRMD="$analysis_dir/reports/ar_report_outbreak.Rmd"
    cp scripts/ar_report_outbreak.Rmd $arRMD
    cp assets/$config_logo_file $analysis_dir/reports

    # prepare report
    micropath="L://Micro/WGS/AR WGS/_outbreak/$OBID/$project_name"
    prepREPORT
fi