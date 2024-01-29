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

if [[ $subworkflow == "DOWNLOAD" ]]; then
	flag_download="Y"
elif [[ $subworkflow == "BATCH" ]]; then
	flag_batch="Y"
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
	# create manifests
	flag_post="Y"
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

## final analysis output
analysis_dir=$output_dir/analysis
report_dir=$analysis_dir/reports
intermed_dir=$analysis_dir/intermed
fasta_dir=$analysis_dir/fasta
qc_dir=$analysis_dir/qc/data
ncbi_dir=$output_dir/ncbi/data
tree_dir=$intermed_dir/tree
val_dir=$intermed_dir/val
amr_dir=$intermed_dir/amr

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

# set project shorthand
project_name=$(echo $project_name_full | cut -f1 -d "_" | cut -f1 -d " ")

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
	if [[ -f tmp.txt ]]; then rm tmp.txt; fi
	for f in *ds*/*; do
		new=`echo $f  | sed "s/_S[0-9].*//g" | cut -f2 -d"/" | sed "s/_R[1,2]//g" | sed "s/.fastq.gz//g"`
		echo "$new" >> tmp.txt
	done
	cat tmp.txt | uniq | grep -v "output" > $sample_id_file

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
			pipeline_batch_dir=$pipeline_dir/batch_$batch_count
        fi
        	
        #echo sample id to the batch
 		echo ${sample_id} >> $batch_manifest
               	
		# prepare samplesheet
        echo "${sample_id},$pipeline_batch_dir/$sample_id.R1.fastq.gz,$pipeline_batch_dir/$sample_id.R2.fastq.gz">>$samplesheet

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
		head -2 $batch_manifest > $log_dir/manifests/batch_01.txt
		#tail -2 $batch_manifest > $log_dir/manifests/batch_02.txt

		# fix samplesheet
		mv $log_dir/manifests/samplesheet* $log_dir/manifests/save
		samplesheet=$log_dir/manifests/save/samplesheet_01.csv
		head -3 $samplesheet > $log_dir/manifests/samplesheet_01.csv
		head -1 $samplesheet > $log_dir/manifests/samplesheet_02.csv
		#tail -2 $samplesheet >> $log_dir/manifests/samplesheet_02.csv
		#sed -i "s/batch_1/batch_2/g" $log_dir/manifests/samplesheet_02.csv

		# update sampleids files
		mv $log_dir/manifests/sample_ids.txt $log_dir/manifests/save
		cat $log_dir/manifests/batch_01.txt > $log_dir/manifests/sample_ids.txt
		#cat $log_dir/manifests/batch_02.txt >> $log_dir/manifests/sample_ids.txt

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
if [[ $flag_analysis == "Y" ]]; then
	#log
	message_cmd_log "--Processing batches:"

	# determine number of batches
	batch_count=`ls $log_dir/manifests/batch* | rev | cut -d'/' -f 1 | rev | tail -1 | cut -f2 -d"0" | cut -f1 -d"."`
	batch_min=`ls $log_dir/manifests/batch* | rev | cut -d'/' -f 1 | rev | head -1 | cut -f2 -d"0" | cut -f1 -d"."`

	#for each batch
	for (( batch_id=$batch_min; batch_id<=$batch_count; batch_id++ )); do

		# set batch name
		if [[ "$batch_id" -gt 9 ]]; then batch_name=$batch_id; else batch_name=0${batch_id}; fi
		
		#set batch manifest, dirs
		batch_manifest=$log_dir/manifests/batch_${batch_name}.txt
		pipeline_batch_dir=$pipeline_dir/batch_$batch_id
		samplesheet=$log_dir/manifests/samplesheet_0$batch_id.csv
		if [[ ! -d $pipeline_batch_dir ]]; then mkdir $pipeline_batch_dir; fi

		# read text file
		IFS=$'\n' read -d '' -r -a sample_list < $batch_manifest

		#create proj tmp dir to enable multiple projects to be run simultaneously
		project_number=`$config_basespace_cmd list projects --filter-term="${project_name_full}" | sed -n '4 p' | awk '{split($0,a,"|"); print a[3]}' | sed 's/ //g'`
		workingdir=$pipeline_batch_dir/$project_number
		if [[ ! -d $workingdir ]]; then mkdir $workingdir; fi

		# set command
		pipeline_full_cmd="$analysis_cmd $analysis_cmd_trailing --input $samplesheet --kraken2db $config_kraken2_db --outdir $pipeline_batch_dir --projectID $project_name_full"

		if [[ $resume == "Y" ]]; then
			cd $workingdir
			message_cmd_log "----Resuming pipeline at $workingdir"
			echo "$pipeline_full_cmd"
			$pipeline_full_cmd
		else
			# print number of lines in file without file name "<"
			n_samples=`wc -l < $batch_manifest`
			echo "----Batch_$batch_id ($n_samples samples): $batch_manifest"
			echo "----Batch_$batch_id ($n_samples samples)" >> $pipeline_log

			#run per sample, handle files
			for sample_id in ${sample_list[@]}; do
				# grab only the sampleID - inconsistent naming is a problem
				shortID=`echo $sample_id | cut -f1 -d"-"`
				
				# move files to batch fasta dir
				mv $tmp_dir/*${shortID}*/*fastq.gz $pipeline_batch_dir
					
				# remove downloaded tmp dir
				rm -r --force $tmp_dir/${sample_id}_[0-9]*/
			done

			# rename all ID files
			## batch manifests
			cleanmanifests $batch_manifest
			cleanmanifests $samplesheet
			cleanmanifests $log_dir/manifests/sample_ids.txt
			
			## fastq files renamed
			for f in $pipeline_batch_dir/*gz; do
				new=`echo $f | sed "s/_S[0-9].*_L001//g" | sed "s/_001//g" | sed "s/[_-]ASTVAL//g" |  sed "s/[_-]AST//g" | sed "s/-$project_name_full//g" | sed "s/-$project_name//g" | sed "s/-OH//g" | sed "s/_R/.R/g"`
				if [[ $new != $f ]]; then mv $f $new; fi
			done

			#log
			message_cmd_log "------ANALYSIS"
			echo "-------Starting time: `date`" >> $pipeline_log
			echo "-------Starting space: `df . | sed -n '2 p' | awk '{print $5}'`" >> $pipeline_log
			
			#run NEXTLFOW
			cd $workingdir
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
			echo "-------Ending time: `date`" >> $pipeline_log
			echo "-------Ending space: `df . | sed -n '2 p' | awk '{print $5}'`" >> $pipeline_log

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

	# read in final report; create sample list
	sample_ids=$output_dir/logs/manifests/sample_ids.txt
	tmp_pipe=$output_dir/analysis/intermed/tmp_pipe.txt
    IFS=$'\n' read -d '' -r -a sample_list < $sample_ids
    
	# save file during dev
	random="sed -i "s/pipeline_/${RANDOM}_pipeline/g" ${pipeline_results}"
	cp $pipeline_results $random
	cp $pipeline_results $pipeline_results_clean
	sed -i "s/\t/;/g" $pipeline_results_clean
	
	# read in all samples
	for id in "${sample_list[@]}"; do
		
		# pull the sample ID
		specimen_id=$id
		SID=$(awk -F";" -v sid=$specimen_id '{ if ($1 == sid) print NR }' $pipeline_results_clean)
        # echo $SID

		# pull the needed variables
		Auto_QC_Outcome=`cat $pipeline_results_clean | awk -F";" -v i=$SID 'FNR == i {print $2}'`
		Estimated_Coverage=`cat $pipeline_results_clean | awk -F";" -v i=$SID 'FNR == i {print $4}' | cut -f1 -d"."`

		# check if the failure is real
		cov_replace="coverage_below_30($Estimated_Coverage)"
		if [[ $Estimated_Coverage -gt 29 ]]; then
			awk -F";" -v i=$SID 'BEGIN {OFS = FS} NR==i {$2="PASS"}1' $pipeline_results_clean > $tmp_pipe
		else
			awk -F";" -v i=$SID -v cov=$cov_replace 'BEGIN {OFS = FS} NR==i {$24=cov}1' $pipeline_results_clean > $tmp_pipe
		fi
		
		# clean up coverage
		sed -i "s/coverage_below_30(0)//g" $tmp_pipe
		
		# save new output
		cp $tmp_pipe $pipeline_results_clean
    done

	# cleanup
	mv $pipeline_results_clean $pipeline_results
	rm $tmp_pipe
fi