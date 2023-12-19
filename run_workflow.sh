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
source $(dirname "$0")/bin/core_functions.sh

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
rawdata_dir=$output_dir/rawdata
tmp_dir=$output_dir/tmp
ar_dir=$output_dir/ar

# set files
final_results=$analysis_dir/reports/final_results_$date_stamp.csv
pipeline_log=$log_dir/pipeline_log.txt
multiqc_config="$log_dir/conf/config_multiqc.yaml"
pipeline_config="$log_dir/conf/config_pipeline.yaml"
ar_config="$log_dir/conf/config_ar.config"

# ncbi dir to hold until completion of sampling
ncbi_hold="../ncbi_hold/$project_id"

############################################
qc_dir=$output_dir/qc
intermed_dir=$analysis_dir/intermed
intermed_sample_dir=$intermed_dir/sample_level_data/assembly

if [[ "$pipeline" == "init" ]]; then

        # print message
        echo
        echo "*** INITIALIZING PIPELINE ***"

        #make directories, logs
        if [[ ! -d $output_dir ]]; then mkdir $output_dir; fi

        ##parent
        dir_list=(logs rawdata pipeline tmp analysis)
        for pd in "${dir_list[@]}"; do if [[ ! -d $output_dir/$pd ]]; then mkdir -p $output_dir/$pd; fi; done

        ## tmp
        dir_list=(fastqc unzipped)
        for pd in "${dir_list[@]}"; do if [[ ! -d $tmp_dir/$pd ]]; then mkdir -p $tmp_dir/$pd; fi; done

	## logs
	dir_list=(conf manifests pipeline gisaid ncbi)
        for pd in "${dir_list[@]}"; do if [[ ! -d $log_dir/$pd ]]; then mkdir -p $log_dir/$pd; fi; done

        ## analysis
        dir_list=(fasta intermed qc reports)
        for pd in "${dir_list[@]}"; do if [[ ! -d $analysis_dir/$pd ]]; then mkdir -p $analysis_dir/$pd; fi; done
	
        ## qc
        dir_list=(sample_level_data)
        for pd in "${dir_list[@]}"; do if [[ ! -d $analysis_dir/qc/$pd ]]; then mkdir -p $analysis_dir/qc/$pd; fi; done

	#### fasta
	dir_list=(not_uploaded gisaid_complete upload_failed)
        for pd in "${dir_list[@]}"; do if [[ ! -d $analysis_dir/fasta/$pd ]]; then mkdir -p $analysis_dir/fasta/$pd; fi; done

        ## tmp
        dir_list=(fastqc unzipped)
        for pd in "${dir_list[@]}"; do if [[ ! -d $analysis_dir/tmp/$pd ]]; then mkdir -p $analysis_dir/tmp/$pd; fi; done

        ##log file
        touch $pipeline_log

	# copy config inputs to edit if doesn't exit
	files_save=("conf/config_pipeline.yaml" "conf/config_multiqc.yaml")
  	for f in ${files_save[@]}; do
        IFS='/' read -r -a strarr <<< "$f"
    	if [[ ! -f "${log_dir}/conf/${strarr[1]}" ]]; then
            cp $f "${log_dir}/conf/${strarr[1]}"
		fi
	done

	#update metadata name
	sed -i "s~metadata.csv~${log_dir}/manifests/metadata-${project_name}.csv~" "${log_dir}/conf/config_pipeline.yaml" 

  	#output
	echo -e "Configs are ready to be edited:\n${log_dir}/conf"
	echo "*** INITIALIZATION COMPLETE ***"
	echo
#########################################
       
elif [[ "$pipeline" == "validation" ]]; then
        # remove prev runs
        sudo rm -rf ~/output/OH-VH00648-230526_AST
	
        # init
        bash run_workflow.sh -p init -n OH-VH00648-230526_AST 

	# run through workflow
        bash run_workflow.sh -p analysis -n OH-VH00648-230526_AST -s DOWNLOAD -t Y
        # bash run_workflow.sh -p analysis -n OH-VH00648-230526_AST -s BATCH -t Y
        # cp -r ~/output/OH-VH00648-230526/savelogs ~/output/OH-VH00648-230526/logs
	# cp  -r ~/output/OH-VH00648-230526/savetmp ~/output/OH-VH00648-230526/tmp
        #bash run_workflow.sh -p analysis -n OH-VH00648-230526_AST -s ANALYZE -t Y
        
elif [[ "$pipeline" == "analysis" ]]; then

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
                "${subworkflow}" \
                "${resume}" \
                "${testing}"

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

elif [[ "$pipeline" == "report" ]]; then

        #############################################################################################
        # Run reporting
        #############################################################################################
        message_cmd_log "------------------------------------------------------------------------"
        message_cmd_log "--- STARTING REPORTING ---"

        bash bin/core_reporting.sh \
                "${output_dir}" \
                "${report_flag}"

fi