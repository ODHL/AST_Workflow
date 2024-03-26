#########################################################
# ARGS
#########################################################
output_dir=$1
pipeline_config=$2
pipeline_log=$3
resume=$4
subworkflow=$5

#########################################################
# Pipeline controls
########################################################
flag_analysis="N"
flag_post="N"
flag_cleanup="N"

if [[ $subworkflow == "ANALYZE" ]]; then
	flag_analysis="Y"
elif [[ $subworkflow == "POST" ]]; then
	flag_post="Y"
elif [[ $subworkflow == "ALL" ]]; then
	flag_analysis="Y"
	flag_post="Y"
fi

##########################################################
# Eval, source
#########################################################
source $(dirname "$0")/core_functions.sh
eval $(parse_yaml ${pipeline_config} "config_")

project_name=$(echo $project_name_full | cut -f1 -d "_" | cut -f1 -d " ")
#########################################################
# Set dirs, files, args
#########################################################
# set dirs
log_dir=$output_dir/logs
tmp_dir=$output_dir/tmp
pipeline_dir=$output_dir/tmp/pipeline/tree
REFDIR=~/home/ubuntu/tools/samestr/db_240313
SAMESTR_DB=$REFDIR/SAMESTR_DB
SAMESTR_EXT=$REFDIR/SAMESTR_EXT
makeDirs $REFDIR
makeDirs $SAMESTR_DB
makeDirs $SAMESTR_EXT

# set variables
ODH_version=$config_ODH_version

# set cmd and log
if [[ $resume == "Y" ]]; then
	echo "----Resuming pipeline at $pipeline_dir"
    message_cmd_log "-------Resuming time: `date`"
	message_cmd_log "-------Resuming space: `df . | sed -n '2 p' | awk '{print $5}'`"
    analysis_cmd=`echo $config_analysis_cmd -resume`
else
	echo "----Starting pipeline at $pipeline_dir"
	message_cmd_log "-------Starting time: `date`"
	message_cmd_log "-------Starting space: `df . | sed -n '2 p' | awk '{print $5}'`"
    analysis_cmd=$config_analysis_cmd
fi
analysis_cmd_trailing=$config_dbs_cmd_trailing

#############################################################################################
# Analysis
#############################################################################################
if [[ $flag_analysis == "Y" ]]; then
	#log
	message_cmd_log "------------------------------------------------------------------------"
	message_cmd_log "--- CONFIG INFORMATION ---"
	message_cmd_log "Analysis date: `date`"
	message_cmd_log "Pipeline version: $ODH_version"
	message_cmd_log "MetaPhlAn version: $config_MetaPhlAn_db"
	message_cmd_log "------------------------------------------------------------------------"

	message_cmd_log "------------------------------------------------------------------------"
	message_cmd_log "--Creating DBS:"
	message_cmd_log "------------------------------------------------------------------------"

    # Run pipeline
    cd $pipeline_dir
	pipeline_full_cmd="$analysis_cmd $analysis_cmd_trailing --outdir $pipeline_dir"
	echo "$pipeline_full_cmd"
	$pipeline_full_cmd

	# log
	message_cmd_log "-------Ending time: `date`"
	message_cmd_log "-------Ending space: `df . | sed -n '2 p' | awk '{print $5}'`"
fi

if [[ $flag_post == "Y" ]]; then
	message_cmd_log "------------------------------------------------------------------------"
	message_cmd_log "--Moving Dbs"
	message_cmd_log "------------------------------------------------------------------------"
	
	#############################################################################################
	# Move DBs
	#############################################################################################	
	cp $pipeline_dir/SAMESTR_DB/* $SAMESTR_DB
	cp $pipeline_dir/SAMESTR_EXT/* $SAMESTR_EXT
	cp $pipeline_dir/pipeline_info/* $REFDIR

	#############################################################################################
	# CLEANUP
	#############################################################################################	
	if [[ -f $merged_roary ]] && [[ -f $merged_tree ]] && [[ -f $merged_snp ]]; then
		message_cmd_log "--Pipeline Completed `date`"
		rm -rf $pipeline_dir
		rm -rf $trimm_dir
	else
		message_cmd_log "--Pipeline FAILED `date`"
		exit
	fi
fi