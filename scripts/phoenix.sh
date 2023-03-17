#########################################################
# ARGS
#########################################################
output_dir=$1
project_name_full=$2
pipeline_config=$3
multiqc_config=$4
date_stamp=$5
pipeline_log=$6
qc_flag=$7
resume_flag=$8

#########################################################
# Pipeline controls
########################################################
if [[ $resume_flag == "Y" ]]; then
	flag_download="N"
	flag_batch="N"
	flag_phoenix="N"
	flag_cleanup="N"
	flag_reporting="N"
	flag_resume="Y"
else
	flag_download="Y"
	flag_batch="Y"
	flag_phoenix="Y"
	flag_cleanup="N"
	flag_reporting="Y"
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

# set variables
phoenix_version=$config_phoenix_version

# set cmd
phoenix_cmd=$config_phoenix_cmd
phoenix_cmd_resume=$config_phoenix_cmd_resume
phoenix_cmd_trailing=$config_phoenix_cmd_trailing

#############################################################################################
# PHOENIX UPDATES
#############################################################################################

#############################################################################################
# LOG INFO TO CONFIG
#############################################################################################
message_cmd_log "------------------------------------------------------------------------"
message_cmd_log "--- CONFIG INFORMATION ---"
message_cmd_log "Sequence run date: $date_stamp"
message_cmd_log "Analysis date: `date`"
message_cmd_log "Phoenix version: $phoenix_version"

message_cmd_log "------------------------------------------------------------------------"
message_cmd_log "--- STARTING PHOENIX ANALYSIS ---"

echo "Starting time: `date`" >> $pipeline_log
echo "Starting space: `df . | sed -n '2 p' | awk '{print $5}'`" >> $pipeline_log

#############################################################################################
# Project Downloads
#############################################################################################	
if [[ $flag_download == "Y" ]]; then
	#get project id
	project_id=`$config_basespace_cmd list projects --filter-term="${project_name_full}" | sed -n '4 p' | awk '{split($0,a,"|"); print a[3]}' | sed 's/ //g'`
	
	# if the project name does not match completely with basespace an ID number will not be found
	# display all available ID's to re-run project	
	if [ -z "$project_id" ] && [ "$partial_flag" != "Y" ]; then
		echo "The project id was not found from $project_name_full. Review available project names below and try again"
		exit
	fi

	# download samples from basespace
	message_cmd_log "--Downloading analysis files (this may take a few minutes to begin)"
	echo "---Starting time: `date`" >> $pipeline_log
	
	$config_basespace_cmd download project --quiet -i $project_id -o "$tmp_dir" --extension=gz
	
	echo "---Ending time: `date`" >> $pipeline_log
	echo "---Ending space: `df . | sed -n '2 p' | awk '{print $5}'`" >> $pipeline_log

fi
#############################################################################################
# Batching
#############################################################################################
if [[ $flag_batch == "Y" ]]; then
	#break project into batches of N = batch_limit set above, create manifests for each
	sample_count=1
	batch_count=0

	# All project ID's download from BASESPACE will be processed into batches
	# Batch count depends on user input from pipeline_config.yaml
	echo "--Creating batch files"
	
	#create sample_id file - grab all files in dir, split by _, exclude noro- file names
	ls $tmp_dir | grep "ds"| cut -f1 -d "-" | grep -v "noro.*" > $sample_id_file

    	#read in text file with all project id's
    	IFS=$'\n' read -d '' -r -a sample_list < $sample_id_file
	
	for sample_id in ${sample_list[@]}; do
        
		#if the sample count is 1 then create new batch
	    if [[ "$sample_count" -eq 1 ]]; then
    	    batch_count=$((batch_count+1))

        	#remove previous versions of batch log
        	if [[ "$batch_count" -gt 9 ]]; then batch_name=$batch_count; else batch_name=0${batch_count}; fi
			
			#remove previous versions of batch log
			batch_manifest=$log_dir/batch_${batch_name}.txt
            if [[ -f $batch_manifest ]]; then rm $batch_manifest; fi
        	
	        # remove previous versions of samplesheet
			samplesheet=$samplesheet_dir/samplesheet_${batch_name}.csv	
			if [[ -f $samplesheet ]]; then rm $samplesheet; fi

        	#create batch manifest
	        touch $batch_manifest

			# create samplesheet
			echo "sample,fastq_1,fastq_2" > $samplesheet_dir/samplesheet_${batch_name}.csv

			# create batch dirs
			fastq_batch_dir=$fastq_dir/batch_$batch_count
        fi
        	
        	#echo sample id to the batch
 		echo ${sample_id} >> $batch_manifest
               	
		# prepare samplesheet
            echo "${sample_id},$fastq_batch_dir/$sample_id.R1.fastq.gz,$fastq_batch_dir/$sample_id.R2.fastq.gz">>$samplesheet

    	#increase sample counter
        ((sample_count+=1))
            
	    #reset counter when equal to batch_limit
    	if [[ "$sample_count" -gt "$config_batch_limit" ]]; then sample_count=1; fi
	done
	
	#gather final count
	sample_count=${#sample_list[@]}
    batch_min=1
	
	# For testing scenarios two batches of two samples will be run
	# Take the first four samples and remove all other batches
	if [[ "$testing_flag" == "Y" ]]; then
		# create save dir for new batches
		mkdir -p $log_dir/save
		batch_manifest=$log_dir/batch_01.txt

		# grab the first two samples and last two samples, save as new batches
		head -2 $batch_manifest > $log_dir/save/batch_01.txt
		tail -2 $batch_manifest > $log_dir/save/batch_02.txt

		# remove old  manifests
		rm $log_dir/batch_*

		# replace update manifests and cleanup
		mv $log_dir/save/* $log_dir
		sudo rm -r $log_dir/save

		# set new batch count
		batch_count=2
		sample_count=4
	fi

	#log
	message_cmd_log "--A total of $sample_count samples will be processed in $batch_count batches, with a maximum of $config_batch_limit samples per batch"

	#merge all batched outputs
	touch $merged_samples
	touch $merged_phoenix
	touch $merged_summary
	touch $merged_fragment
fi
#############################################################################################
# Analysis
#############################################################################################
if [[ $flag_phoenix == "Y" ]]; then
	#log
	message_cmd_log "--Processing batches:"

	#for each batch
	for (( batch_id=$batch_min; batch_id<=$batch_count; batch_id++ )); do

		# set batch name
		if [[ "$batch_id" -gt 9 ]]; then batch_name=$batch_id; else batch_name=0${batch_id}; fi
		
		#set batch manifest, dirs
		batch_manifest=$log_dir/batch_${batch_name}.txt
		fastq_batch_dir=$fastq_dir/batch_$batch_id
		phoenix_batch_dir=$phoenix_dir/batch_$batch_id
		pipeline_logs_batch_dir=$pipeline_logs/batch_$batch_id
		if [[ ! -d $fastq_batch_dir ]]; then mkdir $fastq_batch_dir; fi
		if [[ ! -d $phoenix_batch_dir ]]; then mkdir $phoenix_batch_dir; fi
		if [[ ! -d $pipeline_logs_batch_dir ]]; then mkdir $pipeline_logs_batch_dir; fi

		#read text file
		IFS=$'\n' read -d '' -r -a sample_list < $batch_manifest

		# print number of lines in file without file name "<"
		n_samples=`wc -l < $batch_manifest`
		echo "----Batch_$batch_id ($n_samples samples)"
		echo "----Batch_$batch_id ($n_samples samples)" >> $pipeline_log

		#run per sample, prepare FQ files
		for sample_id in ${sample_list[@]}; do

	    	# move files to batch fasta dir
        	mv $tmp_dir/*${sample_id}*/*fastq.gz $fastq_batch_dir
        		
			# remove downloaded tmp dir
	        rm -r --force $tmp_dir/${sample_id}_[0-9]*/
		done

		#log
		message_cmd_log "------PHOENIX"
		echo "-------Starting time: `date`" >> $pipeline_log
    	echo "-------Starting space: `df . | sed -n '2 p' | awk '{print $5}'`" >> $pipeline_log
	
		# changes in software adds project name to some sample_ids. In order to ensure consistency throughout naming and for downstream
        # uploading, project name should be removed.
        cd $fastq_batch_dir
		for f in $fastq_batch_dir/*; do
                        	
			# creat second proj name if there is additional info IE _AST
			project_name_sub=`echo $project_name_full | cut -f1 -d"_"`
			
			# remove projectid from header
            sed -i "s/-$project_name_full//g" $f
			sed -i "s/-$project_name_sub//g" $f

            # rename files
			## files are named 2023019435-OH-M2941-230301_S16_L001_R2_001.fastq.gz
			## find the R1/2 ID; remove project name; remove after the _S
			Rid=`echo $f | awk -F"_R" '{print $2}' | cut -f1 -d"_"`
            remove_proj=`echo $f | awk -v p_id=-$project_name_full '{ gsub(p_id,"",$1) ; print }'`
			remove_proj=`echo $remove_proj | sed "s/-$project_name_sub//g"`
			remove_trailing=`echo $remove_proj | awk -F"_S" '{print $1}'`
			new_id="$remove_trailing.R$Rid.fastq.gz"
			mv $f $new_id
        done

		#create proj tmp dir to enable multiple projects to be run simultaneously
		if [[ ! -d $project_id ]]; then mkdir $project_id; fi
		cd $project_id
		
		# prepare samplesheet
		samplesheet=$log_dir/samplesheets/samplesheet_0$batch_id.csv

		# run phoenix
		phoenix_full_cmd="$phoenix_cmd $phoenix_version $phoenix_cmd_trailing"
		phoenix_cmd_line="$HOME/nextflow run $phoenix_full_cmd --input $samplesheet --kraken2db $config_kraken2_db --outdir $phoenix_batch_dir"
		echo "$phoenix_cmd_line"
		$phoenix_cmd_line

		# log
    	echo "-------Ending time: `date`" >> $pipeline_log
		echo "-------Ending space: `df . | sed -n '2 p' | awk '{print $5}'`" >> $pipeline_log

		#############################################################################################
		# cleanup
		#############################################################################################
		# move reports
		cat $phoenix_batch_dir/Phoenix_Output_Report.tsv >> $final_results
		mv $phoenix_batch_dir/*/*.t* $analysis_dir/sample_reports

		# move fastqs
		mv $phoenix_batch_dir/*/fastp_trimd/*.fastq.gz $analysis_dir/fasta

		# move logs
		mv $phoenix_batch_dir/pipeline_info/* $pipeline_logs_batch_dir
		mv $phoenix_batch_dir/*/*.synopsis $pipeline_logs_batch_dir

		# move qc
		mv $phoenix_batch_dir/multiqc/multiqc_report.html $qc_dir
		mv $phoenix_batch_dir/*/fastp_trimd/*html $analysis_dir/qc

		# intermeds
		dir_list=(AMRFinder ANI Annotation Assembly gamma_* kraken2_* mlst quast removedAdapters fastp_trimd)
		for d in ${dir_list[@]}; do
			short_name=`echo $d | cut -f1 -d"_"`
			if [[ ! -d $intermed_dir/$short_name ]]; then mkdir $intermed_dir/$short_name; fi
			mv $phoenix_batch_dir/*/$d/* $intermed_dir/$short_name
		done

		#remove intermediate files
		if [[ $flag_cleanup == "Y" ]]; then
			sudo rm -r --force $phoenix_batch_dir
			sudo rm -r --force $fastq_batch_dir
		fi
	done
fi

if [[ $flag_resume == "Y" ]]; then
	echo "Resuming the pipeline"
		
	# set samplesheet
	samplesheet=$log_dir/samplesheets/samplesheet_01.csv

	# batch dir
	phoenix_batch_dir=$phoenix_dir/batch_1
	work_dir=$fastq_dir/batch_1/3*/work

	# run phoenix
	phoenix_full_cmd="$phoenix_cmd_resume $phoenix_version $phoenix_cmd_trailing"
    phoenix_cmd_line="$HOME/nextflow run $phoenix_full_cmd --input $samplesheet --kraken2db $config_kraken2_db -w $work_dir --outdir $phoenix_batch_dir"
	echo "$phoenix_cmd_line"
	$phoenix_cmd_line
fi

#############################################################################################
# Create final reports
#############################################################################################
if [[ $flag_reporting == "Y" ]]; then
	if [[ "$qc_flag" == "Y" ]]; then
		#log
		message_cmd_log "--Creating QC Report"
		echo "---Starting time: `date`" >> $pipeline_log
		echo "---Starting space: `df . | sed -n '2 p' | awk '{print $5}'`" >> $pipeline_log

		#create fragment plot
		python3 scripts/fragment_plots.py $merged_fragment $fragement_plot
	fi 
	
	if [[ $flag_cleanup == "Y" ]]; then
		#remove all proj files
		rm -r --force $tmp_dir
		rm -r --force $phoenix_dir
		rm -r --force $fastq_dir
	fi

	echo "Ending time: `date`" >> $pipeline_log
	echo "Ending space: `df . | sed -n '2 p' | awk '{print $5}'`" >> $pipeline_log
	message_cmd_log "--- PHOENIX PIPELINE COMPLETE ---"
	message_cmd_log "------------------------------------------------------------------------"
fi
