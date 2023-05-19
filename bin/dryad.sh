#########################################################
# ARGS
#########################################################
output_dir=$1
project_name_full=$2
pipeline_config=$3
multiqc_config=$4
date_stamp=$5
pipeline_log=$6
resume_flag=$7

#########################################################
# Pipeline controls
########################################################
if [[ $resume_flag == "Y" ]]; then
	flag_dryad="N"
	flag_resume="Y"
else
	flag_dryad="Y"
	flag_resume="N"
fi
##########################################################
# Eval, source
#########################################################
source $(dirname "$0")/functions.sh
eval $(parse_yaml ${pipeline_config} "config_")
#########################################################
# Set dirs, files, args
#########################################################
# set dirs
fasta_dir=$analysis_dir/fasta
dryad_dir=$output_dir/dryad
fastq_dir=$output_dir/fastq
tmp_dir=$output_dir/tmp
log_dir=$output_dir/logs
pipeline_logs="$log_dir/pipeline_logs"

# set variables
dryad_version=$config_dryad_version

# set cmd
nextflow_cmd=$config_nextflow_cmd
dryad_cmd=$config_dryad_cmd
ref_fasta=$config_ref_fasta

#############################################################################################
# LOG INFO TO CONFIG
#############################################################################################
message_cmd_log "------------------------------------------------------------------------"
message_cmd_log "--- CONFIG INFORMATION ---"
message_cmd_log "Sequence run date: $date_stamp"
message_cmd_log "Analysis date: `date`"
message_cmd_log "Dryad version: $dryad_version"

message_cmd_log "------------------------------------------------------------------------"
message_cmd_log "--- STARTING Dryad ANALYSIS ---"

echo "Starting time: `date`" >> $pipeline_log
echo "Starting space: `df . | sed -n '2 p' | awk '{print $5}'`" >> $pipeline_log

#############################################################################################
# Dryad Analysis
#############################################################################################
# first pass
if [[ $flag_dryad == "Y" ]]; then
	# determine number of batches
	batch_count=`ls $log_dir/batch* | wc -l`
	batch_min=1
	
	#for each batch
	for (( batch_id=$batch_min; batch_id<=$batch_count; batch_id++ )); do

		# handle batches greater than 9
        if [[ "$batch_count" -gt 9 ]]; then batch_name=$batch_count; else batch_name=0${batch_count}; fi

		# set dirs
        fastq_batch_dir=$fastq_dir/batch_$batch_id
		dryad_batch_dir=$dryad_dir/batch_$batch_id
		if [[ ! -d $dryad_batch_dir ]]; then mkdir $dryad_batch_dir; fi

		# log
		message_cmd_log "------DRYAD"
		echo "-------Starting time: `date`" >> $pipeline_log
    	echo "-------Starting space: `df . | sed -n '2 p' | awk '{print $5}'`" >> $pipeline_log
	
		#create proj tmp dir to enable multiple projects to be run simultaneously
		if [[ ! -d $tmp_dir/batch_$batch_id ]]; then mkdir $tmp_dir/batch_$batch_id ; fi
		cd $tmp_dir/batch_$batch_id 

		# run command
        dryad_full_cmd="$dryad_cmd"
		dryad_cmd_line="$nextflow_cmd run $dryad_full_cmd \
        --reads $fastq_batch_dir \
        --outdir $dryad_batch_dir \
		--snp_reference $ref_fasta"
		echo "$dryad_cmd_line"
		$dryad_cmd_line

		~/tools/nextflow run ~/tools/dryad/ \
		-r 3.0.1 \
		--reads /home/ubuntu/output/OH-M2941-230301/fastq/batch_1/set1 \
		--outdir $HOME/output/test_dryad_github \
		--snp_reference /home/ubuntu/refs/MN908947.3.fasta

		# log
    	echo "-------Ending time: `date`" >> $pipeline_log
		echo "-------Ending space: `df . | sed -n '2 p' | awk '{print $5}'`" >> $pipeline_log
	done
fi

# resume
if [[ $flag_resume == "Y" ]]; then
	echo "--Resuming the pipeline"
	
    # determine number of batches
	batch_count=`ls $log_dir/batch* | wc -l`
	batch_min=1
	
	#for each batch
	for (( batch_id=$batch_min; batch_id<=$batch_count; batch_id++ )); do
        # batch dir
        fastq_batch_dir=$fastq_dir/batch_$batch_id
		dryad_batch_dir=$dryad_dir/batch_$batch_id
		if [[ ! -d $dryad_batch_dir ]]; then mkdir $dryad_batch_dir; 

        # run dryad
        dryad_full_cmd="$dryad_cmd"
		dryad_cmd_line="$nextflow_cmd run $dryad_full_cmd -resume \
        --reads $fastq_batch_dir \
        --outdir $dryad_batch_dir \
		--snp_reference $ref_fasta"
		echo "$dryad_cmd_line"
		$dryad_cmd_line
    done
fi