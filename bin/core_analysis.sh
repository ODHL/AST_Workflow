#########################################################
# ARGS
#########################################################
output_dir=$1
project_name_full=$2
pipeline_config=$3
multiqc_config=$4
date_stamp=$5
pipeline_log=$6
subworkflow=$7
resume=$8
testing=$9

echo "TESTING $testing"
#########################################################
# Pipeline controls
########################################################
flag_download="N"
flag_batch="N"
flag_analysis="N"
flag_ID="N"
flag_report="N"
flag_cleanup="N"

if [[ $subworkflow == "DOWNLOAD" ]]; then
	flag_download="Y"
elif [[ $subworkflow == "BATCH" ]]; then
	flag_batch="Y"
elif [[ $subworkflow == "ANALYZE" ]]; then
	flag_analysis="Y"
elif [[ $subworkflow == "REPORT" ]]; then
	flag_report="Y"
elif [[ $subworkflow == "ID" ]]; then
	flag_ID="Y"
elif [[ $subworkflow == "CLEAN" ]]; then
	flag_cleanup="Y"
elif [[ $subworkflow == "ALL" ]]; then
	flag_download="Y"
	flag_batch="Y"
	flag_analysis="Y"
	flag_ID="Y"
	flag_report="Y"
	flag_cleanup="Y"
elif [[ $subworkflow == "lala" ]]; then
	# create manifests
	ls
	# for f in *ds*/*; do
	# 	new=`echo $f  | sed "s/_[0-9].*//g"`
	# 	echo "$new"
	# done
else
	echo "CHOOSE CORRECT FLAG -s: DOWNLOAD BATCH ANALYZE REPORT ID CLEAN ALL"
	echo "YOU CHOOSE: $subworkflow"
	EXIT
fi
##########################################################
# Eval, source
#########################################################
source $(dirname "$0")/core_functions.sh
eval $(parse_yaml ${pipeline_config} "config_")

#########################################################
# Set dirs, files, args
#########################################################
# set dirs
log_dir=$output_dir/logs

# pipeline raw output
pipeline_dir=$output_dir/pipeline
rawdata_dir=$output_dir/rawdata

## final analysis output
analysis_dir=$output_dir/analysis
sample_reports=$analysis_dir/sample_reports
intermed_dir=$analysis_dir/intermed
fasta_dir=$analysis_dir/fasta

## QC output
qc_dir=$output_dir/qc

## tmp dir
tmp_dir=$output_dir/tmp

# set files
merged_pipeline=$intermed_dir/pipeline_results.txt
merged_fragment=$qc_dir/fragment.txt
sample_id_file=$log_dir/manifests/sample_ids.txt
fragement_plot=$qc_dir/fragment_plot.png
final_results=$analysis_dir/final_results_$date_stamp.csv

touch $final_results

# set variables
ODH_version=$config_ODH_version
phoenix_version=$config_phoenix_version
dryad_version=$config_dryad_version

# set cmd
analysis_cmd=$config_analysis_cmd
analysis_cmd_resume=$config_analysis_cmd_resume
analysis_cmd_trailing=$config_analysis_cmd_trailing
nextflow_cmd=$config_nextflow_cmd

# set project shorthand
project_name=$(echo $project_name_full | cut -f1 -d "_" | cut -f1 -d " ")
#############################################################################################
# LOG INFO TO CONFIG
#############################################################################################
message_cmd_log "------------------------------------------------------------------------"
message_cmd_log "--- CONFIG INFORMATION ---"
message_cmd_log "Sequence run date: $date_stamp"
message_cmd_log "Analysis date: `date`"
message_cmd_log "Pipeline version: $ODH_version"
message_cmd_log "Phoenix version: $phoenix_version"
message_cmd_log "Dryad version: $dryad_version"

message_cmd_log "------------------------------------------------------------------------"
message_cmd_log "--- RUNNING ANALYSIS ---"

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
		$config_basespace_cmd list projects
		exit
	fi

	# download samples from basespace
	message_cmd_log "--Downloading analysis files (this may take a few minutes to begin)"
	echo "---Starting time: `date`" >> $pipeline_log
	
	$config_basespace_cmd download project --quiet -i $project_id -o "$tmp_dir" --extension=gz
	
	echo "---Ending time: `date`" >> $pipeline_log
	echo "---Ending space: `df . | sed -n '2 p' | awk '{print $5}'`" >> $pipeline_log

	# remove the "_S39_L001" and "_001" from the file name
	for f in $tmp_dir/*ds*/*; do
		new=`echo $f  | sed "s/_S[0-9].*_L001//g" | sed "s/_001//g"`
		mv $f $new
	done
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

	# remove _ in bank dirs to avoid downstream ID errors
	for dir in $tmp_dir/Bank*; do
		update_dir=`echo $dir | sed "s/Bank_/Bank/g"`
		if [[ $dir != $update_dir ]]; then mv $dir $update_dir; fi

		# handle FASTQ files to match parent dir name
		for fq in $update_dir/*; do
			update_fq=`echo $fq | sed "s/Bank-/Bank/g"`
			if [[ $fq != $update_fq ]]; then mv $fq $update_fq; fi
		done
	done

	# create manifests
	cd $tmp_dir
	for f in *ds*/*; do
		new=`echo $f  | sed "s/_[0-9].*//g"`
		echo "$new" | cut -f2 -d"/" | sed "s/.fastq.gz//g" >> $sample_id_file
	done

    #read in text file with all project id's
	IFS=$'\n' read -d '' -r -a sample_list < $sample_id_file
	
	# break project into batches of N = batch_limit create manifests for each
	sample_count=1
	batch_count=0
	for sample_id in ${sample_list[@]}; do
        
		#if the sample count is 1 then create new batch
	    if [[ "$sample_count" -eq 1 ]]; then
    	    batch_count=$((batch_count+1))

        	# handle more than 9 batches
        	if [[ "$batch_count" -gt 9 ]]; then batch_name=$batch_count; else batch_name=0${batch_count}; fi
			
			#remove previous versions of batch log
			batch_manifest=$log_dir/manifests/batch_${batch_name}.txt
            if [[ -f $batch_manifest ]]; then rm $batch_manifest; fi
        	
	        # remove previous versions of samplesheet
			samplesheet=$log_dir/manifests/samplesheet_${batch_name}.csv	
			if [[ -f $samplesheet ]]; then rm $samplesheet; fi

			# create samplesheet
			echo "sample,fastq_1,fastq_2" > $log_dir/manifests/samplesheet_${batch_name}.csv

			# create batch dirs
			fastq_batch_dir=$rawdata_dir/batch_$batch_count
        fi
        	
        #echo sample id to the batch
 		echo ${sample_id} >> $batch_manifest
               	
		# prepare samplesheet
        echo "${sample_id},$fastq_batch_dir/$sample_id.R1.fastq.gz,$fastq_batch_dir/$sample_id.R2.fastq.gz">>$samplesheet

    	#increase sample counter
    	((sample_count+=1))
            
    	#reset counter when equal to batch_limit
    	if [[ "$sample_count" -gt "$config_batch_limit" ]]; then sample_count=1; fi

		# set final count
		sample_final=`cat $sample_id_file | wc -l`
	done
	
	# For testing scenarios two batches of two samples will be run
	# Take the first four samples and remove all other batches
	if [[ "$testing" == "Y" ]]; then
		echo "--running testing params"

		# create save dir for new batches
		mkdir -p $log_dir/manifests/save
		mv $log_dir/manifests/b*.txt $log_dir/manifests/save
		batch_manifest=$log_dir/manifests/save/batch_01.txt
		head -4 $batch_manifest > $log_dir/manifests/batch_01.txt
		#tail -2 $batch_manifest > $log_dir/save/batch_02.txt

		# fix samplesheet
		mv $log_dir/manifests/samplesheet* $log_dir/manifests/save
		samplesheet=$log_dir/manifests/save/samplesheet_01.csv
		head -5 $samplesheet > $log_dir/manifests/samplesheet_01.csv
		# head -1 $samplesheet > $log_dir/manifests/samplesheet_02.csv
		# tail -2 $samplesheet >> $log_dir/manifests/samplesheet_02.csv
		# sed -i "s/batch_1/batch_2/g" $log_dir/manifests/samplesheet_02.csv

		# set samples and batch
		sample_final=4
		batch_count=2
	fi

	#log
	message_cmd_log "--A total of $sample_final samples will be processed in $batch_count batches, with a maximum of $config_batch_limit samples per batch"
fi

#############################################################################################
# Analysis
#############################################################################################
# first pass
if [[ $flag_analysis == "Y" ]]; then
	#log
	message_cmd_log "--Processing batches:"

	# determine number of batches
	batch_count=`ls $log_dir/manifests/batch* | wc -l`
	batch_min=1

	#for each batch
	for (( batch_id=$batch_min; batch_id<=$batch_count; batch_id++ )); do

		# set batch name
		if [[ "$batch_id" -gt 9 ]]; then batch_name=$batch_id; else batch_name=0${batch_id}; fi
		
		#set batch manifest, dirs
		batch_manifest=$log_dir/manifests/batch_${batch_name}.txt
		fastq_batch_dir=$rawdata_dir/batch_$batch_id
		pipeline_batch_dir=$pipeline_dir/batch_$batch_id
		samplesheet=$log_dir/manifests/samplesheet_0$batch_id.csv
		if [[ ! -d $fastq_batch_dir ]]; then mkdir $fastq_batch_dir; fi
		if [[ ! -d $pipeline_batch_dir ]]; then mkdir $pipeline_batch_dir; fi

		#create proj tmp dir to enable multiple projects to be run simultaneously
		project_number=`$config_basespace_cmd list projects --filter-term="${project_name_full}" | sed -n '4 p' | awk '{split($0,a,"|"); print a[3]}' | sed 's/ //g'`
		if [[ ! -d $project_number ]]; then mkdir $project_number; fi

		if [[ $resume == "Y" ]]; then
			cd $project_number
	
			message_cmd_log "----Resuming pipeline"
			pipeline_full_cmd="$ODH_version $analysis_cmd_trailing"
			analysis_cmd_line="$nextflow_cmd run /home/ubuntu/workflows/AST_Workflow/main.nf $analysis_cmd_resume $pipeline_full_cmd --input $samplesheet --kraken2db $config_kraken2_db --outdir $pipeline_batch_dir --projectID $project_name_full"
			echo "$analysis_cmd_line"
			$analysis_cmd_line
		else
			# read text file
			IFS=$'\n' read -d '' -r -a sample_list < $batch_manifest

			# print number of lines in file without file name "<"
			n_samples=`wc -l < $batch_manifest`
			echo "----Batch_$batch_id ($n_samples samples): $batch_manifest"
			echo "----Batch_$batch_id ($n_samples samples)" >> $pipeline_log

			#run per sample, prepare FQ files
			for sample_id in ${sample_list[@]}; do
				# move files to batch fasta dir
				mv $tmp_dir/*${sample_id}*/*fastq.gz $fastq_batch_dir
					
				# remove downloaded tmp dir
				rm -r --force $tmp_dir/${sample_id}_[0-9]*/
			done

			# rename all ID files
			## batch manifests
			sed -i "s/-$project_name_full//g" $batch_manifest
			sed -i "s/-$project_name//g" $batch_manifest
			sed -i "s/-$project_name_full//g" $samplesheet
			sed -i "s/-$project_name//g" $samplesheet
			
			## fastq files renamed
			for f in $fastq_batch_dir/*; do
				new=`echo $f | sed "s/_S[0-9].*_L001//g" | sed "s/_001//g" | sed "s/[_-]AST//g" | sed "s/-$project_name_full//g" | sed "s/-$project_name//g" | sed "s/_R/.R/g"`
				if [[ $new != $f ]]; then mv $f $new; fi
			done

			# rename all ID files
			## batch manifests
			sed -i "s/[_-]AST//g" $batch_manifest; sed -i "s/-$project_name_full//g" $batch_manifest
			sed -i "s/-$project_name//g" $batch_manifest
			sed -i "s/[_-]AST//g" $samplesheet; sed -i "s/-$project_name_full//g" $samplesheet
			sed -i "s/-$project_name//g" $samplesheet

			#log
			message_cmd_log "------ANALYSIS"
			echo "-------Starting time: `date`" >> $pipeline_log
			echo "-------Starting space: `df . | sed -n '2 p' | awk '{print $5}'`" >> $pipeline_log
			# move to the proj dir so work dir is saved
			cd $pipeline_batch_dir
			
			# run NEXTLFOW
			cd $project_number
			pipeline_full_cmd="$analysis_cmd $ODH_version $analysis_cmd_trailing"
			analysis_cmd_line="$nextflow_cmd run /home/ubuntu/workflows/AST_Workflow/main.nf $pipeline_full_cmd --input $samplesheet --kraken2db $config_kraken2_db --outdir $pipeline_batch_dir --projectID $project_name_full"
			echo "$analysis_cmd_line"
			$analysis_cmd_line
		fi

		# log
    	echo "-------Ending time: `date`" >> $pipeline_log
		echo "-------Ending space: `df . | sed -n '2 p' | awk '{print $5}'`" >> $pipeline_log
	done
fi

#############################################################################################
# Generate WGS ID
#############################################################################################
if [[ $flag_ID == "Y" ]]; then
	#log
	message_cmd_log "--Generating WGS ID's:"

	# determine number of batches
	batch_count=`ls $log_dir/batch* | wc -l`
	batch_min=1

	#for each batch
	for (( batch_id=$batch_min; batch_id<=$batch_count; batch_id++ )); do
		
		# set batch name
		if [[ "$batch_id" -gt 9 ]]; then batch_name=$batch_id; else batch_name=0${batch_id}; fi
		
		#set batch manifest
		batch_manifest=$log_dir/batch_${batch_name}.txt

		#read text file
		IFS=$'\n' read -d '' -r -a sample_list < $batch_manifest

		#run per sample
		for sample_id in ${sample_list[@]}; do
			search_key=`cat $wgs_database | grep $sample_id`

			# if the sample already exists in the database, send an error
			if [[ $search_key == "" ]]; then
				echo "The sampleID $sample_id was already found in the database. Review the results and correct"
				echo $search_key
			else
				final_key=`cat $wgs_database | cut -f2 -d"," | cut -f YYYY-GZ-0001`
			fi
		done
	done
fi
