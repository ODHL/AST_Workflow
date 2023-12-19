#!/bin/bash


#############################################################################################
# Background documentation
#############################################################################################
# Basespace
# https://developer.basespace.illumina.com/docs/content/documentation/cli/cli-examples#Downloadallrundata

#Docker location
# https://hub.docker.com/u/staphb


#############################################################################################
# functions
#############################################################################################

helpFunction()
{
   echo ""
   echo "Usage: $1 -p [REQUIRED] pipeline runmode"
   echo -e "\t-p options: init, analysis, cleanup, report"
   echo "Usage: $2 -n [REQUIRED] project_id"
   echo -e "\t-n project id"
   echo "Usage: $3 -s [OPTIONAL] subworkflow options"
   echo -e "\t-s DOWNLOAD, BATCH, ANALYZE REPORT CLEAN ALL | PREP UPLOAD QC"
   echo "Usage: $4 -r [OPTIONAL] resume_run"
   echo -e "\t-r Y,N option to resume a partial run settings (default N)"
   echo "Usage: $5 -t [OPTIONAL] testing_flag"
   echo -e "\t-t Y,N option to run test settings (default N)"
   echo "Usage: $6 -o [OPTIONAL] report_flag"
   echo -e "\t-o type of report [BASIC OUTBREAK NOVEL REGIONAL TIME]"

   exit 1 # Exit script after printing help
}

while getopts "p:n:s:r:t:o:" opt
do
   case "$opt" in
        p ) pipeline="$OPTARG" ;;
        n ) project_id="$OPTARG" ;;
        s ) subworkflow="$OPTARG" ;;
       	r ) resume="$OPTARG" ;;
       	t ) testing="$OPTARG" ;;
        o ) report_flag="$OPTARG" ;;
        ? ) helpFunction ;; # Print helpFunction in case parameter is non-existent
   esac
done

# Print helpFunction in case parameters are empty
if [ -z "$pipeline" ] || [ -z "$project_id" ]; then
   echo "Some or all of the parameters are empty";
   helpFunction
fi

#set defaults for optional resume
if [ -z "$resume" ]; then resume="N"; fi
if [ -z "$testing" ]; then testing="N"; fi

#############################################################################################
# other functions
#############################################################################################
check_initialization(){
  if [[ ! -d $log_dir ]] || [[ ! -f "$pipeline_config" ]]; then
    echo "ERROR: You must initalize the dir before beginning pipeline"
    exit 1
  fi
}

# source global functions
source $(dirname "$0")/scripts/core_functions.sh

#############################################################################################
# args
#############################################################################################
# Remove trailing / to project_name if it exists
# some projects may have additional information (IE OH-1234 SARS ONLY) in the name
# To avoid issues within project naming schema remove all information after spaces
# To ensure consistency in all projects, remove all information after _
project_name_full=$(echo $project_id | sed 's:/*$::')
project_name=$(echo $project_id | cut -f1 -d "_" | cut -f1 -d " ")

# set date
date_stamp=`echo 20$project_name | sed 's/OH-[A-Z]*[0-9]*-//'`

#############################################################################################
# Dir, Configs
#############################################################################################
# set dirs
output_dir="/home/ubuntu/output/$project_name"
log_dir=$output_dir/logs
analysis_dir=$output_dir/analysis
tmp_dir=$output_dir/tmp
ar_dir=$output_dir/ar

# set files
## results of pipeline
pipeline_results=$analysis_dir/intermed/pipeline_results.tsv
wgs_results=$analysis_dir/intermed/pipeline_results_wgs.tsv
ncbi_results=$analysis_dir/intermed/pipeline_results_ncbis.csv

final_results=$analysis_dir/reports/final_results_$date_stamp.csv
pipeline_log=$log_dir/pipeline_log.txt
multiqc_config="$log_dir/config/config_multiqc.yaml"
pipeline_config="$log_dir/config/config_pipeline.yaml"
ar_config="$log_dir/config/config_ar.config"

# ncbi dir to hold until completion of sampling
ncbi_hold="../ncbi_hold/$project_id"

############################################
qc_dir=$output_dir/qc
intermed_dir=$analysis_dir/intermed
intermed_sample_dir=$intermed_dir/sample_level_data/assembly

#############################################################################################
# Run Phases
#############################################################################################
#bash run_workflow.sh -n OH-VH00648-231120_ASTVAL -p phase1
if [[ $pipeline == "phase1" ]]; then
        # remove prev runs
        sudo rm -rf ~/output/$project_name
	
        # init
        bash run_workflow.sh -p init -n $project_id

	# run through analysis workflow
        bash run_workflow.sh -p analysis -n $project_id -s ALL -t Y

        # create WGS ids
        bash run_workflow.sh -p wgs -n $project_id

        # prep for NCBI
        bash run_workflow.sh -p ncbi_upload -n $project_id

elif [[ $pipeline == "phase2" ]]; then
        
        # merge NCBI output
        bash run_workflow.sh -p ncbi_download -n $project_id

        # create basic report
        bash run_workflow.sh -p report -n $project_id

#############################################################################################
# Run init
#############################################################################################
elif [[ "$pipeline" == "init" ]]; then

        # make directories, logs
        if [[ ! -d $output_dir ]]; then mkdir $output_dir; fi

        # parent
        dir_list=(logs pipeline tmp analysis ncbi)
        for pd in "${dir_list[@]}"; do if [[ ! -d $output_dir/$pd ]]; then mkdir -p $output_dir/$pd; fi; done

	## ncbi
	dir_list=(data)
        for pd in "${dir_list[@]}"; do if [[ ! -d $output_dir/ncbi/$pd ]]; then mkdir -p $output_dir/ncbi/$pd; fi; done

        ## logs
	dir_list=(config manifests pipeline gisaid ncbi)
        for pd in "${dir_list[@]}"; do if [[ ! -d $log_dir/$pd ]]; then mkdir -p $log_dir/$pd; fi; done

        ## analysis
        dir_list=(fasta intermed qc reports)
        for pd in "${dir_list[@]}"; do if [[ ! -d $analysis_dir/$pd ]]; then mkdir -p $analysis_dir/$pd; fi; done
	
        #### qc
        dir_list=(data)
        for pd in "${dir_list[@]}"; do if [[ ! -d $analysis_dir/qc/$pd ]]; then mkdir -p $analysis_dir/qc/$pd; fi; done

	#### fasta
	dir_list=(not_uploaded gisaid_complete upload_failed)
        for pd in "${dir_list[@]}"; do if [[ ! -d $analysis_dir/fasta/$pd ]]; then mkdir -p $analysis_dir/fasta/$pd; fi; done

        #### tmp
        dir_list=(fastqc unzipped)
        for pd in "${dir_list[@]}"; do if [[ ! -d $analysis_dir/tmp/$pd ]]; then mkdir -p $analysis_dir/tmp/$pd; fi; done

        ##log file
        touch $pipeline_log

	# copy config inputs to edit if doesn't exit
	files_save=("config/config_pipeline.yaml" "config/config_multiqc.yaml")
  	for f in ${files_save[@]}; do
        IFS='/' read -r -a strarr <<< "$f"
    	if [[ ! -f "${log_dir}/config/${strarr[1]}" ]]; then
            cp $f "${log_dir}/config/${strarr[1]}"
		fi
	done

	#update metadata name
        sed -i "s~METADATAFILE~${log_dir}/manifests/${project_name}_AST_patient_data.csv~" "${log_dir}/config/config_pipeline.yaml"

  	#output
        echo "------------------------------------------------------------------------"
	echo "--- INITIALIZATION COMPLETE ---"
        echo "------------------------------------------------------------------------"
	echo -e "Configs are ready to be edited:\n${log_dir}/conf"
#############################################################################################
#############################################################################################
# Run analysis
#############################################################################################
elif [[ "$pipeline" == "analysis" ]]; then
        message_cmd_log "------------------------------------------------------------------------"
        message_cmd_log "--- STARTING ANALYSIS ---"
        message_cmd_log "------------------------------------------------------------------------"

        # check initialization was completed
        check_initialization

        # Eval YAML args
        date_stamp=`echo 20$project_name | sed 's/OH-[A-Z]*[0-9]*-//'`

        # run pipelien
        bash scripts/core_analysis.sh \
                "${output_dir}" \
                "${project_name_full}" \
                "${pipeline_config}" \
                "${multiqc_config}" \
                "${date_stamp}" \
                "${pipeline_log}" \
                "${subworkflow}" \
                "${resume}" \
                "${testing}"
#############################################################################################
# Run ID
#############################################################################################
elif [[ "$pipeline" == "wgs" ]]; then
        message_cmd_log "------------------------------------------------------------------------"
        message_cmd_log "--- ASSIGNING IDS ---"
        bash scripts/core_wgs_id.sh $analysis_dir $project_name $pipeline_results $wgs_results
#############################################################################################
# Run NCBI
#############################################################################################
elif [[ "$pipeline" == "ncbi_upload" ]]; then
        message_cmd_log "------------------------------------------------------------------------"
        message_cmd_log "--- PREPARING NCBI UPLOAD ---"
        message_cmd_log "------------------------------------------------------------------------"
        
        bash scripts/core_ncbi.sh \
        $output_dir $project_name $pipeline_config $pipeline_results $wgs_results $ncbi_results "UPLOAD"
elif [[ "$pipeline" == "ncbi_download" ]]; then        
        message_cmd_log "------------------------------------------------------------------------"
        message_cmd_log "--- PREPARING NCBI DOWNLOAD ---"
        message_cmd_log "------------------------------------------------------------------------"
        
        bash scripts/core_ncbi.sh \
        $output_dir $project_name $pipeline_config $pipeline_results $wgs_results $ncbi_results "DOWNLOAD"
#############################################################################################
# Run reporting
#############################################################################################
elif [[ "$pipeline" == "report" ]]; then
        message_cmd_log "------------------------------------------------------------------------"
        message_cmd_log "--- STARTING REPORTING ---"
        message_cmd_log "------------------------------------------------------------------------"
        bash scripts/core_report.sh \
                $output_dir \
                $project_name \
                $pipeline_results \
                $wgs_results \
                $ncbi_results \
                $subworkflow

#############################################################################################
# Run cleanup
#############################################################################################
elif [[ "$pipeline" == "cleanup" ]]; then
        message_cmd_log "------------------------------------------------------------------------"
        message_cmd_log "--- STARTING CLEANUP ---"
        bash scripts/core_cleanup.sh \
                "${output_dir}" \
                "${project_name_full}" \
                "${pipeline_config}"
#############################################################################################
# Run validation
#############################################################################################
elif [[ "$pipeline" == "validation" ]]; then
        # # remove prev runs
        # sudo rm -rf ~/output/OH-M5185-230830
	
        # # init
        # bash run_workflow.sh -p init -n OH-M5185-230830

	# # run through workflow
        # bash run_workflow.sh -p analysis -n OH-M5185-230830 -s DOWNLOAD -t Y
        # # # cp -r ~/output/OH-VH00648-230526/savelogs ~/output/OH-VH00648-230526/logs
	# # # cp  -r ~/output/OH-VH00648-230526/savetmp ~/output/OH-VH00648-230526/tmp
        # bash run_workflow.sh -p analysis -n OH-M5185-230830 -s BATCH -t Y
        # # # cat ~/output/OH-M5185-230830/logs/manifests/batch_01.txt
        # bash run_workflow.sh -p analysis -n OH-M5185-230830 -s ANALYZE -t Y
        # # bash run_workflow.sh -p analysis -n OH-M5185-230830 -s WGS -t Y
        # # bash run_workflow.sh -p analysis -n OH-M5185-230830 -s NCBI -t Y

        # bash run_workflow.sh -p analysis -n OH-M5185-230830 -s ANALYZE -t Y -r Y
        # bash  /home/ubuntu/workflows/AR_Workflow/wgs_db/testing LORENZO ID
        # bash scripts/core_wgs_id.sh /home/ubuntu/output/OH-M5185-230830/analysis \
                # /home/ubuntu/output/OH-M5185-230830/analysis/reports/batch_1_GRiPHin_Summary.tsv OH-M5185-230830
        rm -r /home/ubuntu/output/OH-M5185-230830/ncbi/*
        project_name="OH-M5185-230830"
        pipeline_config="/home/ubuntu/output/$project_name/logs/config/config_pipeline.yaml"
        wgs_results="/home/ubuntu/output/$project_name/analysis/reports/pipeline_report_wgs.csv"

        bash scripts/core_ncbi.sh /home/ubuntu/output/OH-M5185-230830 OH-M5185-230830 $pipeline_config $wgs_results
fi