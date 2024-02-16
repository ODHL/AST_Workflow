#!/bin/bash
#########################################################
# ARGS
########################################################
sample_name_list=$1
merge_id=$2

#########################################################
# Pipeline controls
########################################################

#########################################################
# Files, dirs
########################################################
wgs_file="/home/ubuntu/workflows/AR_Workflow/wgs_db/wgs_db_master.csv"
merged_wgs="home/ubuntu/$merged_id/analysis/intermed/pipeline_results_wgs.tsv"
touch $merged_wgs

#########################################################
# Workflow
########################################################
if [[ $flag == "PRE" ]]; then
    # create samplesheet
    samplesheet=$log_dir/manifests/samplesheet_01.csv
    echo "sample,fastq_1,fastq_2" > $samplesheet

    # create pipeline dir
    pipeline_batch_dir= $output_dir/pipeline/batch_01

    #remove previous versions of batch log
    batch_manifest=$log_dir/manifests/batch_01.txt
    if [[ -f $batch_manifest ]]; then rm $batch_manifest; fi

    ## tmp dir
    tmp_dir=$output_dir/tmp

    # create sample list
    IFS=',' read -r -a sample_list <<< "$sample_name_list"

    # prepare the samples
    for sample_id in ${sample_list[@]}; do
        echo "--processing $sample_id"
        
        # create samplesheet
        echo "${sample_id},$pipeline_batch_dir/$sample_id.R1.fastq.gz,$pipeline_batch_dir/$sample_id.R2.fastq.gz">>$samplesheet

        #echo sample id to the batch
        echo ${sample_id} >> $batch_manifest
        
        # download files
        $config_basespace_cmd download biosample --quiet -n "${sample_id}" -o $tmp_dir
    done
else
    
    # create sample list
    IFS=',' read -r -a sample_list <<< "$sample_name_list"

    # prepare the samples
    for sample_id in ${sample_list[@]}; do
        awk '{print $2","$1}' $wgs_file | grep "$sample_id" >> $merged_wgs
    done

fi