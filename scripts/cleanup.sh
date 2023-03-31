#########################################################
# ARGS
#########################################################
output_dir=$1
project_name_full=$2
pipeline_config=$3

##########################################################
# Eval, source
#########################################################
source $(dirname "$0")/functions.sh
eval $(parse_yaml ${pipeline_config} "config_")
#########################################################
# Set dirs, files, args
#########################################################
# set dirs
log_dir=$output_dir/logs
pipeline_logs="$log_dir/pipeline_logs.txt"

phoenix_dir=$output_dir/phoenix
fastq_dir=$output_dir/fastq

analysis_dir=$output_dir/analysis

intermed_dir=$analysis_dir/intermed
intermed_sample_dir=$intermed_dir/sample_level_data
fasta_dir=$analysis_dir/fasta

qc_dir=$output_dir/qc
qc_sample_dir=$qc_dir/sample_level_data

tmp_dir=$output_dir/tmp
#############################################################################################
# set flags
#############################################################################################
flag_cleanup="Y"

#############################################################################################
# LOG INFO TO CONFIG
#############################################################################################
message_cmd_log "------------------------------------------------------------------------"
message_cmd_log "--- STARTING CLEANUP ---"

#############################################################################################
# cleanup
#############################################################################################
if [[ $flag_cleanup == "Y" ]]; then
 	# determine number of batches
	batch_count=`ls $log_dir/batch* | wc -l`
	batch_min=1

	# for each batch
	for (( batch_id=$batch_min; batch_id<=$batch_count; batch_id++ )); do
		echo "--cleaning batch $batch_id"
		
		# handle batches greater than 9
        if [[ "$batch_count" -gt 9 ]]; then batch_name=$batch_count; else batch_name=0${batch_count}; fi

		# set dirs
		phoenix_batch_dir=$phoenix_dir/batch_$batch_id
		dryad_batch_dir=$dryad_dir/batch_$batch_id
		fastq_batch_dir=$fastq_dir/batch_$batch_id
		
		# move qc
		mv $phoenix_batch_dir/multiqc/multiqc_report.html $qc_dir//multiqc_report_batch_$batch_id.html
		mv $phoenix_batch_dir/*/fastp_trimd/*.fastp.html $qc_sample_dir
	
		# move intermeds
		mv $phoenix_batch_dir/*/*_Assembly_ratio*.txt $intermed_sample_dir/ASSEMBLY
		mv $phoenix_batch_dir/*/AMRFinder/*_all_genes.tsv $intermed_sample_dir/AMRFinder
		mv $phoenix_batch_dir/*/AMRFinder/*_all_mutations.tsv $intermed_sample_dir/AMRFinder
 		mv $phoenix_batch_dir/*/ANI/fastANI/*fastANI.txt $intermed_sample_dir/ANI
 		mv $phoenix_batch_dir/*/mlst/*_combined.tsv $intermed_sample_dir/MLST

		# move report
		mv $phoenix_batch_dir/Phoenix_Output_Report.tsv $analysis_dir/Phoenix_Output_Report_batch_$batch_id.tsv

		# move logs
		for f in $phoenix_batch_dir/pipeline_info/execution_trace_*; do
			new=`echo $f | cut -f9 -d"/" | sed "s/execution_trace/trace_b$batch_id/g"`
			mv $f $log_dir/pipeline_logs/$new
		done
		
		# move fastq files
		mv $fastq_batch_dir/*.gz $analysis_dir/fasta

		#remove intermediate files
		sudo rm -r --force $phoenix_batch_dir
		sudo rm -r --force $fastq_batch_dir
	done
fi