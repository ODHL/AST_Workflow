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
pipeline_logs="$log_dir/pipeline_logs"
samplesheet_dir=$log_dir/samplesheets

phoenix_dir=$output_dir/phoenix
fastq_dir=$output_dir/fastq

analysis_dir=$output_dir/analysis
sample_reports=$analysis_dir/sample_reports
intermed_dir=$analysis_dir/intermed
fasta_dir=$analysis_dir/fasta

qc_dir=$output_dir/qc

tmp_dir=$output_dir/tmp

# set files
merged_samples=$log_dir/completed_samples.txt
merged_phoenix=$intermed_dir/phoenix_results.txt
merged_fragment=$qc_dir/fragment.txt
sample_id_file=$log_dir/sample_ids.txt
fragement_plot=$qc_dir/fragment_plot.png
final_results=$analysis_dir/final_results_$date_stamp.csv

touch $final_results

#############################################################################################
# LOG INFO TO CONFIG
#############################################################################################
message_cmd_log "------------------------------------------------------------------------"
message_cmd_log "--- STARTING PHOENIX ANALYSIS ---"

#############################################################################################
# cleanup
#############################################################################################
if [[ $flag_cleanup == "Y" ]]; then
	batch_min=1
	batch_count=1
	
	# # for each batch
	# for (( batch_id=$batch_min; batch_id<=$batch_count; batch_id++ )); do
	# 	phoenix_batch_dir=$phoenix_dir/batch_1
	
	# 	# move reports
	# 	cat $phoenix_batch_dir/Phoenix_Output_Report.tsv >> $final_results
	# 	mv $phoenix_batch_dir/*/*.t* $analysis_dir/sample_reports

	# 	# move fastqs
	# 	mv $phoenix_batch_dir/*/fastp_trimd/*.fastq.gz $analysis_dir/fasta

	# 	# move logs
	# 	mv $phoenix_batch_dir/pipeline_info/* $pipeline_logs_batch_dir
	# 	mv $phoenix_batch_dir/*/*.synopsis $pipeline_logs_batch_dir

	# 	# move qc
	# 	mv $phoenix_batch_dir/multiqc/multiqc_report.html $qc_dir
	# 	mv $phoenix_batch_dir/*/fastp_trimd/*html $analysis_dir/qc

	# 	# intermeds
	# 	dir_list=(AMRFinder ANI Annotation Assembly gamma_* kraken2_* mlst quast removedAdapters fastp_trimd)
	# 	for d in ${dir_list[@]}; do
	# 		short_name=`echo $d | cut -f1 -d"_"`
	# 		if [[ ! -d $intermed_dir/$short_name ]]; then mkdir $intermed_dir/$short_name; fi
	# 		mv $phoenix_batch_dir/*/$d/* $intermed_dir/$short_name
	# 	done
		
	# 	#remove intermediate files
	# 	sudo rm -r --force $phoenix_batch_dir
	# 	sudo rm -r --force $fastq_batch_dir
	# doesn
fi