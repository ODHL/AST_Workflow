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
   echo "Usage: $1 -p [REQUIRED] pipeline mode options"
   echo -e "\t-m options: init, all, analysis, cleanup, report"
   echo "Usage: $2 -n [REQUIRED] project_id"
   echo -e "\t-n project id"
   echo "Usage: $3 -r [OPTIONAL] resume_run"
   echo -e "\t-p Y,N option to resume a partial run settings (default N)"
   echo "Usage: $4 -t [OPTIONAL] testing_flag"
   echo -e "\t-t Y,N option to run test settings (default N)"
   echo "Usage: $5 -e [OPTIONAL] testing_flag"
   echo -e "\t-t Y,N option to run test settings (default N)"

   exit 1 # Exit script after printing help
}

check_initialization(){
  if [[ ! -d $log_dir ]] || [[ ! -f "$pipeline_config" ]]; then
    echo "ERROR: You must initalize the dir before beginning pipeline"
    exit 1
  fi
}

# source global functions
source $(dirname "$0")/bin/core_functions.sh


#############################################################################################
# helper function
#############################################################################################
while getopts "p:n:r:t:" opt
do
   case "$opt" in
        p ) pipeline="$OPTARG" ;;
        n ) project_id="$OPTARG" ;;
        r ) resume_flag="$OPTARG" ;;
        t ) testing_flag="$OPTARG" ;;
        ? ) helpFunction ;; # Print helpFunction in case parameter is non-existent
   esac
done

# Print helpFunction in case parameters are empty
if [ -z "$pipeline" ] || [ -z "$project_id" ]; then
   echo "Some or all of the parameters are empty";
   helpFunction
fi

#############################################################################################
# args
#############################################################################################
# Remove trailing / to project_name if it exists
# some projects may have additional information (IE OH-1234 SARS ONLY) in the name
# To avoid issues within project naming schema remove all information after spaces
# To ensure consistency in all projects, remove all information after _
project_name_full=$(echo $project_id | sed 's:/*$::')
project_name=$(echo $project_id | cut -f1 -d "_" | cut -f1 -d " ")
output_dir="/home/ubuntu/output/$project_name"

#set defaults for optional args
if [ -z "$qc_flag" ]; then qc_flag="Y"; fi
if [ -z "$testing_flag" ]; then testing_flag="N"; fi
if [ -z "$resume_flag" ]; then resume_flag="N"; fi

#############################################################################################
# Dir, Configs
#############################################################################################
# set dirs
log_dir=$output_dir/logs

qc_dir=$output_dir/qc

tmp_dir=$output_dir/tmp

analysis_dir=$output_dir/analysis

fasta_dir=$analysis_dir/fasta

intermed_dir=$analysis_dir/intermed
intermed_sample_dir=$intermed_dir/sample_level_data/assembly

#set log files
pipeline_log=$log_dir/pipeline_log.txt

#set configs
multiqc_config="$log_dir/config_multiqc.yaml"
pipeline_config="$log_dir/config_pipeline.yaml"

# set date
date_stamp=`echo 20$project_name | sed 's/OH-[A-Z]*[0-9]*-//'`

if [[ "$pipeline" == "init" ]]; then

        # print message
        echo
        echo "*** INITIALIZING PIPELINE ***"

        #make directories, logs
        if [[ ! -d $output_dir ]]; then mkdir $output_dir; fi

        ##parent
        dir_list=(logs fastq pipeline qc tmp analysis)
        for pd in "${dir_list[@]}"; do if [[ ! -d $output_dir/$pd ]]; then mkdir -p $output_dir/$pd; fi; done

        ## logs
	dir_list=(samplesheets pipeline_logs)
        for pd in "${dir_list[@]}"; do if [[ ! -d $log_dir/$pd ]]; then mkdir -p $log_dir/$pd; fi; done

        ## qc
        dir_list=(sample_level_data)
        for pd in "${dir_list[@]}"; do if [[ ! -d $qc_dir/$pd ]]; then mkdir -p $qc_dir/$pd; fi; done

        ##tmp
        dir_list=(fastqc unzipped)
        for pd in "${dir_list[@]}"; do if [[ ! -d $tmp_dir/$pd ]]; then mkdir -p $tmp_dir/$pd; fi; done

        ##analysis
        dir_list=(fasta intermed sample_reports)
        for pd in "${dir_list[@]}"; do if [[ ! -d $analysis_dir/$pd ]]; then mkdir -p $analysis_dir/$pd; fi; done

        ## intermed
        dir_list=(sample_level_data)
        for pd in "${dir_list[@]}"; do if [[ ! -d $intermed_dir/$pd ]]; then mkdir -p $intermed_dir/$pd; fi; done
        dir_list=(ASSEMBLY AMRFinder ANI MLST)
        for pd in "${dir_list[@]}"; do if [[ ! -d $intermed_sample_dir/$pd ]]; then mkdir -p $intermed_sample_dir/$pd; fi; done

        ##make files
        touch $pipeline_log

        # copy config inputs to edit if doesn't exit
        files_save=("conf/config_pipeline.yaml" "conf/config_multiqc.yaml")
        for f in ${files_save[@]}; do
                IFS='/' read -r -a strarr <<< "$f"
                if [[ ! -f "${log_dir}/${strarr[1]}" ]]; then
                        cp $f "${log_dir}/${strarr[1]}"
                fi
        done

        #output
        echo -e "Configs are ready to be edited:\n${log_dir}"
        echo "*** INITIALIZATION COMPLETE ***"
        echo
elif [[ "$pipeline" == "all" ]] || [[ "$pipeline" == "analysis" ]]; then

        #############################################################################################
        # Run pipeline
        #############################################################################################
        message_cmd_log "------------------------------------------------------------------------"
        message_cmd_log "--- STARTING ANALYSIS ---"

        # check initialization was completed
        check_initialization

        # Eval YAML args
        date_stamp=`echo 20$project_name | sed 's/OH-[A-Z]*[0-9]*-//'`

        # run pipelien
        bash bin/core_analysis.sh \
                "${output_dir}" \
                "${project_name_full}" \
                "${pipeline_config}" \
                "${multiqc_config}" \
                "${date_stamp}" \
                "${pipeline_log}" \
                "${resume_flag}" \
                "${testing_flag}"

elif [[ "$pipeline" == "cleanup" ]]; then

        #############################################################################################
        # Run cleanup
        #############################################################################################
        message_cmd_log "------------------------------------------------------------------------"
        message_cmd_log "--- STARTING CLEANUP ---"

        bash bin/core_cleanup.sh \
                "${output_dir}" \
                "${project_name_full}" \
                "${pipeline_config}"

elif [[ "$pipeline" == "all" ]] || [[ "$pipeline" == "report" ]]; then

        #############################################################################################
        # Run reporting
        #############################################################################################
        message_cmd_log "------------------------------------------------------------------------"
        message_cmd_log "--- STARTING REPORTING ---"

        bash bin/core_reporting.sh \
                "${output_dir}" \
                "${project_name_full}" \
                "${pipeline_config}"

fi