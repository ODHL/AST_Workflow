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
pipeline_results="${10}"

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
elif [[ $subworkflow == "ANALYZE" ]]; then
	flag_analysis="Y"
elif [[ $subworkflow == "CLEAN" ]]; then
	flag_cleanup="Y"
elif [[ $subworkflow == "POST" ]]; then
	flag_post="Y"
elif [[ $subworkflow == "ALL" ]]; then
	flag_batch="Y"
	flag_analysis="Y"
	flag_post="Y"
	flag_cleanup="Y"
elif [[ $subworkflow == "lala" ]]; then
	flag_post="Y"
else
	echo "CHOOSE CORRECT FLAG -s: BATCH ANALYZE CLEAN POST ALL"
	echo "YOU CHOOSE: $subworkflow"
	EXIT
fi
##########################################################
# Eval, source
#########################################################
source $(dirname "$0")/core_functions.sh
eval $(parse_yaml ${pipeline_config} "config_")

#########################################################
# Core dir, Configs
#########################################################
# set dirs
log_dir=$output_dir/logs
tmp_dir=$output_dir/tmp
analysis_dir=$output_dir/analysis
manifest_dir=$log_dir/manifests
pipeline_dir=$output_dir/tmp/pipeline
intermed_dir=$analysis_dir/intermed
qc_dir=$tmp_dir/qc/data
ncbi_dir=$tmpdir/ncbi/data
gff_dir=$tmp_dir/gff
amr_dir=$tmp_dir/amr
dl_dir=$tmp_dir/rawdata/download
fastq_dir=$tmp_dir/rawdata/fastq
trimm_dir=$tmp_dir/rawdata/trimmed

# set files
phoenix_results=$analysis_dir/intermed/pipeline_results_phoenix.tsv
sample_id_file=$log_dir/manifests/sample_ids.txt
lab_results=$log_dir/manifests/labresults.txt

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
IFS=$'\n' read -d '' -r -a sample_list < $sample_id_file	

# create proj tmp dir to enable multiple projects to be run simultaneously
project_number=`$config_basespace_cmd list projects --filter-term="${project_name_full}" | sed -n '4 p' | awk '{split($0,a,"|"); print a[3]}' | sed 's/ //g'`

# set resume command 
if [[ $resume == "Y" ]]; then
	analysis_cmd=`echo $config_analysis_cmd -resume`
else
	analysis_cmd=`echo $config_analysis_cmd`
fi

# set projectID
# check that access to the projectID is available before attempting to download
if [ -z "$project_number" ]; then
	$config_basespace_cmd list projects --filter-term="${project_name_full}"
	project_number="123456789"
fi

#############################################################################################
# Batching
#############################################################################################
if [[ $flag_batch == "Y" ]]; then
	message_cmd_log "------------------------------------------------------------------------"
	message_cmd_log "--- BATCHING ---"
	message_cmd_log "------------------------------------------------------------------------"
	
	#read in text file with all project id's
	IFS=$'\n' read -d '' -r -a raw_list < config/sample_ids.txt
	if [[ -f $sample_id_file ]];then rm $sample_id_file; fi
	if [[ -f $lab_results ]];then rm $lab_results; fi
	for f in ${raw_list[@]}; do
		if [[ $f != "specimen_id" ]]; then 
			echo $f | cut -f1 -d";" | sort >> $sample_id_file
			echo $f | cut -f2 -d";" | sort | sed "s/,/;/g" >> $lab_results
		fi
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
			pipeline_batch_dir=$tmp_dir/pipeline/batch_$batch_name
			makeDirs $pipeline_batch_dir
			makeDirs $pipeline_batch_dir/$project_number
        fi
            
		#echo sample id to the batch
	   	echo ${sample_id} >> $batch_manifest                
		
		# prepare samplesheet
        echo "${sample_id},$fastq_dir/$sample_id.R1.fastq.gz,$fastq_dir/$sample_id.R2.fastq.gz">>$samplesheet

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

	# log
	message_cmd_log "----A total of $sample_final samples will be processed in $batch_count batches, with a maximum of $config_batch_limit samples per batch"
fi

#############################################################################################
# Analysis
#############################################################################################
# determine number of batches
batch_count=`ls $log_dir/manifests/batch* | rev | cut -d'/' -f 1 | rev | tail -1 | cut -f2 -d"0" | cut -f1 -d"."`
batch_min=`ls $log_dir/manifests/batch* | rev | cut -d'/' -f 1 | rev | head -1 | cut -f2 -d"0" | cut -f1 -d"."`
if [[ $flag_analysis == "Y" ]]; then
	
	#############################################################################################
	# LOG INFO TO CONFIG
	#############################################################################################
	message_cmd_log "------------------------------------------------------------------------"
	message_cmd_log "--- CONFIG INFORMATION ---"
	message_cmd_log "------------------------------------------------------------------------"
	message_cmd_log "Sequence run date: $date_stamp"
	message_cmd_log "Analysis date: `date`"
	message_cmd_log "Pipeline version: $ODH_version"
	message_cmd_log "Phoenix version: $phoenix_version"
	message_cmd_log "Dryad version: $dryad_version"
	message_cmd_log "Starting time: `date`"
	message_cmd_log "Starting space: `df . | sed -n '2 p' | awk '{print $5}'`"

	message_cmd_log "------------------------------------------------------------------------"
	message_cmd_log "--- STARTING ANALYSIS ---"
	message_cmd_log "------------------------------------------------------------------------"
	message_cmd_log "Starting time: `date`"
	message_cmd_log "Starting space: `df . | sed -n '2 p' | awk '{print $5}'`"
	message_cmd_log "--Processing batches:"
	
	# create pipeline output file
	if [[ ! -f $phoenix_results ]]; then touch $phoenix_results; fi

	# for each batch
	for (( batch_id=$batch_min; batch_id<=$batch_count; batch_id++ )); do

        # set batch name
		if [[ "$batch_id" -gt 9 ]]; then batch_name=$batch_id; else batch_name=0${batch_id}; fi
		
		# set batch manifest, dirs
		batch_manifest=$manifest_dir/batch_${batch_name}.txt
		samplesheet=$manifest_dir/samplesheet_${batch_name}.csv	
		
		# read text file
		IFS=$'\n' read -d '' -r -a batch_list < $batch_manifest

		# output start message
		message_cmd_log "------------------------------------------------------------------------"
		message_cmd_log "--- DOWNLOADING ---"
		message_cmd_log "------------------------------------------------------------------------"
		message_cmd_log "--Downloading analysis files (this may take a few minutes to begin)"
		message_cmd_log "--Starting time: `date`"
		for sample_id in ${batch_list[@]}; do
			$config_basespace_cmd download biosample --quiet -n "${sample_id}" -o $dl_dir
			mv $dl_dir/$sample_id*/*gz $fastq_dir
		done

		# move to final dir, clean
		for f in $fastq_dir/*gz; do
			new=$(clean_file_names $f)
			if [[ $f != $new ]]; then mv $f $new; fi
		done
		clean_file_insides $samplesheet
		clean_file_insides $batch_manifest
	
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
			cat $pipeline_batch_dir/Phoenix_Summary.tsv >> $phoenix_results
			cp $pipeline_batch_dir/pipeline_info/* $log_dir/pipeline
			cp $pipeline_batch_dir/*/*.synopsis $log_dir/pipeline
			cp $pipeline_batch_dir/*/qc_stats/* $qc_dir
			cp $pipeline_batch_dir/*/annotation/*gff $gff_dir
			cp $pipeline_batch_dir/*/fastp_trimd/*gz $trimm_dir
			cp $pipeline_batch_dir/*/gamma_ar/*.gamma $amr_dir
			cp $pipeline_batch_dir/*/AMRFinder/*_all_genes.tsv $amr_dir

			# log
			message_cmd_log "-------Ending time: `date`"
			message_cmd_log "-------Ending space: `df . | sed -n '2 p' | awk '{print $5}'`"

			#############################################################################################
			# CLEANUP
			#############################################################################################	
			#remove intermediate files
			if [[ $flag_cleanup == "Y" ]] && [[ -f $phoenix_results ]]; then
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
	rm -rf $dl_dir
fi

#############################################################################################
# Output correction
#############################################################################################
if [[ $flag_post == "Y" ]]; then
	#log
	message_cmd_log "------------------------------------------------------------------------"
	message_cmd_log "--- POST ANALYSIS ---"
	message_cmd_log "------------------------------------------------------------------------"

	# create tmp copy of results
	cd $pipeline_dir
	tmp_file=tmp_output.csv
	mlst_file=mlst_output.csv
	if [[ -f $tmp_file ]]; then rm $tmp_file; fi
	if [[ -f $mlst_file ]]; then rm $mlst_file; fi

	cp $phoenix_results $tmp_file
	cp $phoenix_results $pipeline_results
	sed -i "s/\t/;/g" $tmp_file
	sed -i "s/\t/;/g" $pipeline_results

	# review synopsis and determine status
	cat $pipeline_results | awk -F";" '{print $1}' | grep -v "ID" | uniq > processed_samples
	IFS=$'\n' read -d '' -r -a sample_list < processed_samples
	for sample_id in "${sample_list[@]}"; do
		
		# pull only ID
		sample_id=$(clean_file_names $sample_id)

		# set synoposis file
		synopsis=$log_dir/pipeline/$sample_id.synopsis

		# # determine number of warnings, fails
		num_of_warnings=`cat $synopsis | grep -v "WARNINGS" | grep "WARNING" | wc -l`
		num_of_fails=`cat $synopsis | grep -v "completed as FAILED" | grep "FAILED" | wc -l`

		# review lab results
		labValue=`cat $lab_results | grep $sample_id | cut -f2 -d";"`
		pipelineValue=`cat $phoenix_results | grep $sample_id | awk -F"\t" '{print $9}'`
		pipelineStatus=`cat $phoenix_results | grep $sample_id | awk -F"\t" '{print $2}'`

		# message if the lab didnt give results
		if [[ $labValue == "" ]]; then echo "Missing lab value: $sample_id"; fi

		# update the results and reasons
		SID=$(awk -F"\t" -v sid=$sample_id '{ if ($1 == sid) print NR }' $phoenix_results)
		if [[ $num_of_warnings -gt 4 ]]; then
			reason=$(cat $synopsis | grep -v "Summarized" | grep -E "WARNING|FAIL" | awk -F": " '{print $3}' |  awk 'BEGIN { ORS = "; " } { print }' | sed "s/; ; //g")
			cat $phoenix_results | awk -F"\t" -v i=$SID -v reason="${reason}" 'BEGIN {OFS = FS} NR==i {$2="FAIL"; $24=reason}1' > $pipeline_results
		else
			if [[ $pipelineStatus == "PASS" && *"$pipelineValue" != *"$labValue"*  ]]; then
				reason="Lab Discordance"
				cat $phoenix_results | awk -F"\t" -v i=$SID -v reason="${reason}" 'BEGIN {OFS = FS} NR==i {$2="FAIL"; $24=reason}1' > $pipeline_results
				echo "Lab Discordance: $reason"
				exit
			else
				cp $pipeline_results $tmp_file
			fi
		fi

		# set taxonomy
        Species=`cat $phoenix_results | awk -F"\t" -v i=$SID 'FNR == i {print $9}' | sed "s/([0-9]*.[0-9]*%)//g" | sed "s/  //g"`
        MLST_1=`cat $phoenix_results | awk -F"\t" -v i=$SID 'FNR == i {print $16}'| cut -f1 -d","`
        MLST_Scheme_1=`cat $phoenix_results | awk -F"\t" -v i=$SID 'FNR == i {print $15}'`
        MLST_2=`cat $phoenix_results | awk -F"\t" -v i=$SID 'FNR == i {print $18}'| cut -f1 -d","`
        MLST_Scheme_2=`cat $phoenix_results | awk -F"\t" -v i=$SID 'FNR == i {print $17}'`
        
		# handle schemes that have parenthesis
        if [[ $MLST_Scheme_1 =~ "(" ]]; then MLST_Scheme_1=`echo $MLST_Scheme_1 | sed -E -n 's/.*\((.*)\).*$/\1/p'`; fi
        if [[ $MLST_Scheme_2 =~ "(" ]]; then MLST_Scheme_2=`echo $MLST_Scheme_2 | sed -E -n 's/.*\((.*)\).*$/\1/p'`; fi

        # check if the first scheme exists
		if [[ $MLST_1 == "-" ]] || [[ $MLST_1 == *"Novel"* ]]; then
            sequence_classification=""
        else
			# check if there is a second MLST
			if [[ $MLST_2 == "-" ]]; then
				sequence_classification=`echo "ML${MLST_1}_${MLST_Scheme_1}"`
			else
				sequence_classification=`echo "ML${MLST_1}_${MLST_Scheme_1},ML${MLST_2}_${MLST_Scheme_2}"`
			fi
        fi
		
		# Add MLST
		awk -v add="$sequence_classification;$labValue" -v sample="$sample_id" '$0 ~ sample {print $0";"add}' "$pipeline_results" >> "$mlst_file"

		# save changes
		cp $pipeline_results $tmp_file
    done

	# cleanup
	rm $tmp_file
	mv $mlst_file $pipeline_results

	# stats
	head -n 2 $pipeline_results; echo; echo;
	num_samples=`cat $pipeline_results | wc -l`
	num_discordance=`cat $pipeline_results | grep "Discordance" | wc -l`
	num_concordant=`cat $pipeline_results | grep "PASS" | wc -l`
	num_failed=`cat $pipeline_results | grep -v "Discordance" | awk '{print $2}' | grep "FAIL" | wc -l`

	echo "There are $num_samples samples | Lab: $num_concordant (concordant) vs $num_discordance (discordant), $num_failed were failures."
fi