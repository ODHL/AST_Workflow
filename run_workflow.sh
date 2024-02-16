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
   echo -e "\t-p options: phase1, phase2, init, analysis, wgs, ncbi_upload, ncbi_download, report, cleanup"
   echo "Usage: $2 -n [REQUIRED] project_id"
   echo -e "\t-n project id"
   echo "Usage: $3 -s [OPTIONAL] subworkflow options"
   echo -e "\t-s DOWNLOAD, BATCH, ANALYZE REPORT CLEAN ALL | PREP UPLOAD QC"
   echo "Usage: $4 -r [OPTIONAL] resume_run"
   echo -e "\t-r Y,N option to resume a partial run settings (default N)"
   echo "Usage: $5 -t [OPTIONAL] testing_flag"
   echo -e "\t-t Y,N option to run test settings (default N)"
   echo "Usage: $6 -m [OPTIONAL] merged_projects"
   echo -e "\t-m list of comma sep projects"
   echo "Usage: $7 -o [OPTIONAL] report_flag"
   echo -e "\t-o type of report [BASIC OUTBREAK NOVEL REGIONAL TIME]"

   exit 1 # Exit script after printing help
}

while getopts "p:n:s:r:t:m:o:" opt
do
   case "$opt" in
        p ) pipeline="$OPTARG" ;;
        n ) project_id="$OPTARG" ;;
        s ) subworkflow="$OPTARG" ;;
       	r ) resume="$OPTARG" ;;
       	t ) testing="$OPTARG" ;;
        o ) report_flag="$OPTARG" ;;
        m ) merged_projects="$OPTARG" ;;
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
proj_date=`echo 20$project_name | sed 's/OH-[A-Z]*[0-9]*-//' | sed "s/_SARS//g"`
today_date=$(date '+%Y-%m-%d'); today_date=`echo $today_date | sed "s/-//g"`
#############################################################################################
# Dir, Configs
#############################################################################################
# set dirs
output_dir="/home/ubuntu/output/$project_name"
log_dir=$output_dir/logs
tmp_dir=$output_dir/tmp
analysis_dir=$output_dir/analysis
ar_dir=$output_dir/ar

# set files
## results of pipeline
pipeline_results=$analysis_dir/intermed/pipeline_results.tsv
wgs_results=$analysis_dir/intermed/pipeline_results_wgs.tsv
ncbi_results=$analysis_dir/intermed/pipeline_results_ncbis.csv

final_results=$analysis_dir/reports/final_results_$today_date.csv
pipeline_log=$log_dir/pipeline_log.txt
multiqc_config="$log_dir/config/config_multiqc.yaml"
pipeline_config="$log_dir/config/config_pipeline.yaml"
ar_config="$log_dir/config/config_ar.config"

#############################################################################################
#############################################################################################
######################### Run full workflows #########################
#############################################################################################
#############################################################################################
# bash run_workflow.sh -n OH-VH00648-231120_ASTVAL -p phase1
if [[ $pipeline == "phase1" ]]; then
        # init
        bash run_workflow.sh -p init -n $project_id

	# run through analysis workflow
        bash run_workflow.sh -p analysis -n $project_id -s ALL

        # run through tree workflow
        bash run_workflow.sh -p tree -n $project_id -s ALL

        # create WGS ids
        bash run_workflow.sh -p wgs -n $project_id

        # prep for NCBI
        bash run_workflow.sh -p ncbi_upload -n $project_id

elif [[ $pipeline == "phase2" ]]; then
        
        # merge NCBI output
        bash run_workflow.sh -p ncbi_download -n $project_id

        # create basic report
        bash run_workflow.sh -p report -n $project_id -s BASIC

elif [[ "$pipeline" == "phaseV" ]]; then
        # init
        bash run_workflow.sh -p init -n $project_id

	# run through analysis workflow
        bash run_workflow.sh -p analysis -n $project_id -s ALL

        # generate report
        bash validation/ast_validation.sh $subworkflow $project_name_full $output_dir $pipeline_log
elif [[ "$pipeline" == "phaseM" ]]; then
        # init
        bash run_workflow.sh -p init -n $project_id

        # run merged analysis
        bash run_workflow.sh -p merge -n $project_id -m $merged_projects -s PRE

        # run analysis
        bash run_workflow.sh -p analysis -n $project_id -s ANALZYE
        bash run_workflow.sh -p analysis -n $project_id -s POST

        # run merged post
        bash run_workflow.sh -p merge -n $project_id -m $merged_projects -s POST

        # run tree
        bash run_workflow.sh -p tree -n $project_id -s ALL

        # create outbreak report
        bash run_workflow.sh -p report -n $project_id -s OUTBREAK

#############################################################################################
#############################################################################################
################################## Run Individual workflows #################################
#############################################################################################
#############################################################################################
################################## Run init
elif [[ "$pipeline" == "init" ]]; then
        # parent
        dir_list=(logs pipeline tmp analysis ncbi/data)
        for pd in "${dir_list[@]}"; do makeDirs $output_dir/$pd; done

        ## logs
	dir_list=(config manifests/complete pipeline)
        for pd in "${dir_list[@]}"; do makeDirs $log_dir/$pd; done
	touch $log_dir/manifests/sample_ids.txt

        ## analysis
        dir_list=(intermed qc/data reports)
        for pd in "${dir_list[@]}"; do makeDirs $analysis_dir/$pd; done
	
        dir_list=(tree val)
        for pd in "${dir_list[@]}"; do makeDirs $analysis_dir/intermed/$pd; done

        ##log file
        touch $pipeline_log

	# copy config inputs to edit if doesn't exit
	files_save=("config/config_pipeline.yaml" "config/config_multiqc.yaml" "config/config_ar_report.yaml")
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

################################## Run analysis
elif [[ "$pipeline" == "analysis" ]]; then
        # check initialization was completed
        check_initialization

        # run pipelien
        bash scripts/core_analysis.sh \
                "${output_dir}" \
                "${project_name_full}" \
                "${pipeline_config}" \
                "${multiqc_config}" \
                "${proj_date}" \
                "${pipeline_log}" \
                "${subworkflow}" \
                "${resume}" \
                "${testing}"

################################## Run TREE
elif [[ "$pipeline" == "tree" ]]; then
        bash scripts/build_tree.sh \
                "${output_dir}" \
                "${project_name_full}" \
                "${pipeline_config}" \
                "${pipeline_log}" \
                "${resume}" \
                "${subworkflow}"

################################## Run ID
elif [[ "$pipeline" == "wgs" ]]; then
        bash scripts/core_wgs_id.sh \
                $analysis_dir \
                $project_name \
                $pipeline_results \
                $wgs_results
################################## Run NCBI
elif [[ "$pipeline" == "ncbi_upload" ]]; then        
        bash scripts/core_ncbi.sh \
        $output_dir $project_name $pipeline_config $pipeline_results $wgs_results $ncbi_results "UPLOAD"
elif [[ "$pipeline" == "ncbi_download" ]]; then        
        bash scripts/core_ncbi.sh \
        $output_dir $project_name $pipeline_config $pipeline_results $wgs_results $ncbi_results "DOWNLOAD"
################################## Run reporting
elif [[ "$pipeline" == "report" ]]; then
                $output_dir \
                $project_name \
                $pipeline_results \
                $wgs_results \
                $ncbi_results \
                $subworkflow \
                $pipeline_config

################################## Run merge
elif [[ "$pipeline" == "merge" ]]; then
        bash scripts/merge_projects.sh \
                "${merged_projects}" \
                "${project_id}"
######################## Run validation
elif [[ "$pipeline" == "validation" ]]; then
        # generate report
        bash scripts/ast_validation.sh $subworkflow $project_name_full $output_dir $pipeline_log
fi