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

#########################################################
# Pipeline controls
########################################################
flag_download="N"
flag_batch="N"
flag_analysis="N"
flag_cleanup="N"
flag_post="N"

if [[ $subworkflow == "BATCH" ]]; then
	flag_batch="Y"
elif [[ $subworkflow == "DOWNLOAD" ]]; then
	flag_download="Y"
elif [[ $subworkflow == "ANALYZE" ]]; then
	flag_analysis="Y"
elif [[ $subworkflow == "CLEAN" ]]; then
	flag_cleanup="Y"
elif [[ $subworkflow == "POST" ]]; then
	flag_post="Y"
elif [[ $subworkflow == "ALL" ]]; then
	flag_download="Y"
	flag_batch="Y"
	flag_analysis="Y"
	flag_post="Y"
	flag_cleanup="Y"
elif [[ $subworkflow == "lala" ]]; then
	flag_post="Y"
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
manifest_dir=$log_dir/manifests

# pipeline raw output
pipeline_dir=$output_dir/pipeline

## final analysis output
analysis_dir=$output_dir/analysis
intermed_dir=$analysis_dir/intermed
qc_dir=$analysis_dir/qc/data
ncbi_dir=$output_dir/ncbi/data
tree_dir=$intermed_dir/tree
val_dir=$intermed_dir/val

## tmp dir
tmp_dir=$output_dir/tmp

# set files
pipeline_results=$intermed_dir/pipeline_results.tsv
pipeline_results_clean=$intermed_dir/pipeline_results_clean.tsv
sample_id_file=$log_dir/manifests/sample_ids.txt

# set variables
ODH_version=$config_ODH_version
phoenix_version=$config_phoenix_version
dryad_version=$config_dryad_version

# set cmd
analysis_cmd=$config_analysis_cmd
analysis_cmd_trailing=$config_analysis_cmd_trailing
wgsID_script=$config_wgsID_script

#########################################################
# project variables
#########################################################
# set project shorthand
project_name=$(echo $project_name_full | cut -f1 -d "_" | cut -f1 -d " ")

#read in text file with all project id's
IFS=$'\n' read -d '' -r -a sample_list < config/sample_ids.txt
if [[ -f $sample_id_file ]];then rm $sample_id_file; fi
for f in ${sample_list[@]}; do
	if [[ $f != "specimen_id" ]]; then 	echo $f-$project_name >> $sample_id_file; fi
done
IFS=$'\n' read -d '' -r -a sample_list < $sample_id_file	

# create proj tmp dir to enable multiple projects to be run simultaneously
project_number=`$config_basespace_cmd list projects --filter-term="${project_name_full}" | sed -n '4 p' | awk '{split($0,a,"|"); print a[3]}' | sed 's/ //g'`

# set command 
if [[ $resume == "Y" ]]; then
	analysis_cmd=`echo $config_analysis_cmd -resume`
else
	analysis_cmd=`echo $config_analysis_cmd`
fi
#############################################################################################
# LOG INFO TO CONFIG
#############################################################################################
message_cmd_log "--- CONFIG INFORMATION ---"
message_cmd_log "Sequence run date: $date_stamp"
message_cmd_log "Analysis date: `date`"
message_cmd_log "Pipeline version: $ODH_version"
message_cmd_log "Phoenix version: $phoenix_version"
message_cmd_log "Dryad version: $dryad_version"
message_cmd_log "Starting time: `date`"
message_cmd_log "Starting space: `df . | sed -n '2 p' | awk '{print $5}'`"

message_cmd_log "------------------------------------------------------------------------"
message_cmd_log "--- STARTING ANALYSIS ---"

message_cmd_log "Starting time: `date`"
message_cmd_log "Starting space: `df . | sed -n '2 p' | awk '{print $5}'`"

#############################################################################################
# Batching
#############################################################################################
if [[ $flag_batch == "Y" ]]; then
	echo "--Creating batch files"

	#read in text file with all project id's
	IFS=$'\n' read -d '' -r -a raw_list < config/sample_ids.txt
	if [[ -f $sample_id_file ]];then rm $sample_id_file; fi
	for f in ${raw_list[@]}; do
		if [[ $f != "specimen_id" ]]; then 	echo $f-$project_name >> $sample_id_file; fi
	done
	IFS=$'\n' read -d '' -r -a sample_list < $sample_id_file

	# break project into batches of N = batch_limit create manifests for each
	sample_count=1
	batch_count=0
	for sample_id in ${sample_list[@]}; do
        
		#if the sample count is 1 then create new batch
	    if [[ "$sample_count" -eq 1 ]]; then
        	batch_count=$((batch_count+1))
	
        	#remove previous versions of batch log
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
			fastq_batch_dir=$tmp_dir/batch_$batch_name/rawdata
			tmp_batch_dir=$tmp_dir/batch_$batch_name/download
			pipeline_batch_dir=$tmp_dir/batch_$batch_name/pipeline
			makeDirs $fastq_batch_dir
			makeDirs $tmp_batch_dir
			makeDirs $pipeline_batch_dir
			makeDirs $pipeline_batch_dir/$project_number
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

	if [[ "$testing" == "Y" ]]; then
		echo "----creating testing batch file"

		# create save dir for old manifests
		mkdir -p $log_dir/manifests/save
		mv $log_dir/manifests/b*.txt $log_dir/manifests/save
		batch_manifest=$log_dir/manifests/save/batch_01.txt

		# grab the first two samples and last two samples, save as new batches
		head -2 $batch_manifest > $log_dir/manifests/batch_01.txt
		tail -2 $batch_manifest > $log_dir/manifests/batch_02.txt

		# fix samplesheet
		mv $log_dir/manifests/samplesheet* $log_dir/manifests/save
		samplesheet=$log_dir/manifests/save/samplesheet_01.csv
		head -3 $samplesheet > $log_dir/manifests/samplesheet_01.csv
		head -1 $samplesheet > $log_dir/manifests/samplesheet_02.csv
		tail -2 $samplesheet >> $log_dir/manifests/samplesheet_02.csv
		sed -i "s/batch_1/batch_2/g" $log_dir/manifests/samplesheet_02.csv

		# set new batch count
		batch_count=2
		sample_final=4
	fi

	#log
	message_cmd_log "----A total of $sample_final samples will be processed in $batch_count batches, with a maximum of $config_batch_limit samples per batch"
fi

#############################################################################################
# Project Downloads
#############################################################################################	
# determine number of batches
batch_count=`ls $log_dir/manifests/batch* | rev | cut -d'/' -f 1 | rev | tail -1 | cut -f2 -d"0" | cut -f1 -d"."`
batch_min=`ls $log_dir/manifests/batch* | rev | cut -d'/' -f 1 | rev | head -1 | cut -f2 -d"0" | cut -f1 -d"."`
if [[ $flag_download == "Y" ]]; then
	# check that access to the projectID is available before attempting to download
	if [ -z "$project_number" ]; then
		echo "The project id was not found from $project_name_full. Review available project names below and try again"
		$config_basespace_cmd list projects --filter-term="${project_name_full}"
		exit
	fi

	# output start message
	message_cmd_log "--Downloading analysis files (this may take a few minutes to begin)"
	message_cmd_log "---Starting time: `date`"
	
	# for each batch
	for (( batch_id=$batch_min; batch_id<=$batch_count; batch_id++ )); do

        # set batch name
		if [[ "$batch_id" -gt 9 ]]; then batch_name=$batch_id; else batch_name=0${batch_id}; fi
		
		# set batch manifest, dirs
		batch_manifest=$manifest_dir/batch_${batch_name}.txt
		fastq_batch_dir=$tmp_dir/batch_$batch_name/rawdata
		tmp_batch_dir=$tmp_dir/batch_$batch_name/download
		samplesheet=$manifest_dir/samplesheet_${batch_name}.csv	
		
		# read text file
		IFS=$'\n' read -d '' -r -a batch_list < $batch_manifest

		for sample_id in ${batch_list[@]}; do
			$config_basespace_cmd download biosample --quiet -n "${sample_id}" -o $tmp_batch_dir
		done

		# move to final dir, clean
		mv $tmp_batch_dir/*/*gz $fastq_batch_dir
		for f in $fastq_batch_dir/*gz; do
			new=$(clean_file_names $f)
			mv $f $new
		done
		clean_file_insides $samplesheet
		clean_file_insides $batch_manifest
		rm -rf $tmp_batch_dir
	done

	# output end message
	message_cmd_log "---Ending space: `df . | sed -n '2 p' | awk '{print $5}'`" >> $pipeline_log
fi

#############################################################################################
# Analysis
#############################################################################################
if [[ $flag_analysis == "Y" ]]; then
	#log
	message_cmd_log "--Processing batches:"

	#for each batch
	for (( batch_id=$batch_min; batch_id<=$batch_count; batch_id++ )); do

		# set batch name
		if [[ "$batch_id" -gt 9 ]]; then batch_name=$batch_id; else batch_name=0${batch_id}; fi
		
		#set batch manifest, dirs
		batch_manifest=$log_dir/manifests/batch_${batch_name}.txt
		pipeline_batch_dir=$pipeline_dir/batch_$batch_name
		samplesheet=$log_dir/manifests/samplesheet_$batch_name.csv

		# move to project dir
		cd $pipeline_batch_dir/$project_number

		# set command
		pipeline_full_cmd="$analysis_cmd $analysis_cmd_trailing --input $samplesheet --kraken2db $config_kraken2_db --outdir $pipeline_batch_dir --projectID $project_name_full"

		if [[ $resume == "Y" ]]; then
			message_cmd_log "----Resuming pipeline "
			echo "$pipeline_full_cmd"
			$pipeline_full_cmd
		else
			# read text file
			IFS=$'\n' read -d '' -r -a sample_list < $batch_manifest

			# print number of lines in file without file name "<"
			n_samples=`wc -l < $batch_manifest`
			message_cmd_log "----Batch_$batch_id ($n_samples samples)"

			#log
			message_cmd_log "------ANALYSIS"
			message_cmd_log "-------Starting time: `date`"
			message_cmd_log "-------Starting space: `df . | sed -n '2 p' | awk '{print $5}'`"
					
			#run NEXTLFOW
			echo "$pipeline_full_cmd"
			$pipeline_full_cmd
		fi

		#############################################################################################
		# Reporting
		#############################################################################################	
		# check the pipeline has completed
		if [[ -f $pipeline_batch_dir/Phoenix_Summary.tsv ]]; then
			message_cmd_log "---- The pipeline completed batch #$batch_id at `date` "
			message_cmd_log "--------------------------------------------------------"

			# add to  master pipeline results
			cat $pipeline_batch_dir/Phoenix_Summary.tsv >> $pipeline_results
			cp $pipeline_batch_dir/pipeline_info/* $log_dir/pipeline
			cp $pipeline_batch_dir/*/qc_stats/* $qc_dir
			cp $pipeline_batch_dir/*/annotation/*gff $tree_dir
			cp $pipeline_batch_dir/*/fastp_trimd/*gz $tree_dir
			cp $pipeline_batch_dir/*/gamma_ar/*.gamma $val_dir
			cp $pipeline_batch_dir/*/amr/*_all_genes.tsv $val_dir

			# log
			message_cmd_log "-------Ending time: `date`"
			message_cmd_log "-------Ending space: `df . | sed -n '2 p' | awk '{print $5}'`"

			#############################################################################################
			# FASTQ
			#############################################################################################	
			cp $pipeline_batch_dir/*.gz $ncbi_dir

			#############################################################################################
			# CLEANUP
			#############################################################################################	
			#remove intermediate files
			if [[ $flag_cleanup == "Y" ]] && [[ -f $pipeline_results ]]; then
				sudo rm -r --force $pipeline_batch_dir
				mv $batch_manifest $log_dir/manifests/complete
			fi
		else
			message_cmd_log "---- The pipeline failed `date`"
			message_cmd_log "------Missing file: $pipeline_batch_dir/Phoenix_Summary.tsv"
			message_cmd_log "--------------------------------------------------------"
			exit
		fi
	done
fi

#############################################################################################
# Output correction
#############################################################################################
if [[ $flag_post == "Y" ]]; then
	#log
	message_cmd_log "--Quality Analysis"

	# create tmp copy of results
	tmp_file=tmp_output.csv
	cp $pipeline_results $tmp_file
	sed -i "s/\t/;/g" $tmp_file

	if [[ -f $pipeline_results_clean ]]; then rm $pipeline_results_clean; fi
	touch $pipeline_results_clean

	# read in all samples
	for id in "${sample_list[@]}"; do
		
		# pull the needed variables
		SID=$(awk -F";" -v sid=$id '{ if ($1 == sid) print NR }' $tmp_file)
		Auto_QC_Outcome=`cat $tmp_file | awk -F";" -v i=$SID 'FNR == i {print $2}'`
		Estimated_Coverage=`cat $tmp_file | awk -F";" -v i=$SID 'FNR == i {print $4}' | cut -f1 -d"."`

		# check if the failure is real
		cov_replace="coverage_below_30($Estimated_Coverage)"
		if [[ $Estimated_Coverage -gt 29 ]]; then
			awk -F";" -v i=$SID 'BEGIN {OFS = FS} NR==i {$2="PASS"}1' $tmp_file >> $pipeline_results_clean
		else
			awk -F";" -v i=$SID -v cov=$cov_replace 'BEGIN {OFS = FS} NR==i {$24=cov}1' $tmp_file >> $pipeline_results_clean
		fi
		
		# clean up coverage
		sed -i "s/coverage_below_30(0)//g" $pipeline_results_clean
    done

	# cleanup
	rm $tmp_file
fi