#########################################################
# ARGS
#########################################################
flag=$1
project_name_full=$2
resume=$3
output_dir=$4
pipeline_config=$5
pipeline_log=$6

#########################################################
# Pipeline controls
########################################################
# set flags
flag_download="N"
flag_batch="N"
flag_run="N"
flag_cleaning="N"
flag_gamma="N"
flag_kraken="N"
flag_mqc="N"

if [[ $flag == "DOWNLOAD" ]]; then
    flag_download="Y"
elif [[ $flag == "BATCH" ]]; then
    flag_batch="Y"
elif [[ $flag == "ANALYZE" ]]; then
    flag_run="Y"
elif [[ $flag == "GAMMA" ]]; then
	flag_gamma="Y"
elif [[ $flag == "KRAKEN" ]]; then
	flag_kraken="Y"
elif [[ $flag == "MQC" ]]; then
	flag_mqc="Y"
elif [[ $flag == "ALL" ]]; then
    flag_download="Y"
    flag_batch="Y"
    flag_run="Y"
fi

#########################################################
# Set dirs, files, args
#########################################################
# pipeline raw output
pipeline_dir=$output_dir/pipeline

# logdir
log_dir=$output_dir/logs

## tmp dir
tmp_dir=$output_dir/tmp

## final analysis output
analysis_dir=$output_dir/analysis
kraken2_dir=$analysis_dir/intermed/kraken2
gamma_dir=$analysis_dir/intermed/gamma
mqc_dir=$analysis_dir/qc/data

if [[ ! -d $kraken2_dir ]]; then mkdir -p $kraken2_dir; fi
if [[ ! -d $gamma_dir ]]; then mkdir -p $gamma_dir; fi
if [[ ! -d $mqc_dir ]]; then mkdir -p $mqc_dir; fi

# results files
gamma_results="$analysis_dir/intermed/gamma_results_240116.csv"
species_results="$analysis_dir/intermed/species_results_240116.txt"

multiqc_config="$output_dir/logs/config/config_multiqc.yaml"
multiqc_log="$output_dir/logs/log_multiqc.txt"

# set project shorthand
project_name=$(echo $project_name_full | cut -f1 -d "_" | cut -f1 -d " ")
##########################################################
# Eval, source
#########################################################
source /home/ubuntu/workflows/AR_Workflow/scripts/core_functions.sh
eval $(parse_yaml ${pipeline_config} "config_")

cleanmanifests(){
	sed -i "s/[_-]ASTVAL//g" $1
	sed -i "s/[_-]AST//g" $1
	sed -i "s/-$project_name_full//g" $1
	sed -i "s/-$project_name//g" $1		
	sed -i "s/-OH//g" $1		
}

#########################################################
# Run Pipeline
########################################################
if [[ $flag_download == "Y" ]]; then
    rm -rf $output_dir
    bash /home/ubuntu/workflows/AR_Workflow/run_workflow.sh -n $project_name_full -p init

    echo "--downloading"
    bash /home/ubuntu/workflows/AR_Workflow/run_workflow.sh -n $project_name_full -p analysis -s DOWNLOAD
fi

if [[ $flag_batch == "Y" ]]; then
    echo "--batching"
    bash /home/ubuntu/workflows/AR_Workflow/run_workflow.sh -n $project_name_full -p analysis -s BATCH
fi

if [[ $flag_run == "Y" ]]; then
    #log
	echo "--Processing batches:"

	# determine number of batches
	batch_count=`ls $log_dir/manifests/batch* | wc -l`
	batch_min=1

	#for each batch
	for (( batch_id=$batch_min; batch_id<=$batch_count; batch_id++ )); do

		# set batch name
		if [[ "$batch_id" -gt 9 ]]; then batch_name=$batch_id; else batch_name=0${batch_id}; fi
		
		#set batch manifest, dirs
		batch_manifest=$log_dir/manifests/batch_${batch_name}.txt
		fastq_batch_dir=$pipeline_dir/batch_$batch_id
		pipeline_batch_dir=$pipeline_dir/batch_$batch_id
		samplesheet=$log_dir/manifests/samplesheet_0$batch_id.csv
		if [[ ! -d $fastq_batch_dir ]]; then mkdir $fastq_batch_dir; fi
		if [[ ! -d $pipeline_batch_dir ]]; then mkdir $pipeline_batch_dir; fi

		# read text file
		IFS=$'\n' read -d '' -r -a sample_list < $batch_manifest

		#create proj tmp dir to enable multiple projects to be run simultaneously
		project_number=`$config_basespace_cmd list projects --filter-term="${project_name_full}" | sed -n '4 p' | awk '{split($0,a,"|"); print a[3]}' | sed 's/ //g'`
		workingdir=$pipeline_batch_dir/$project_number
		if [[ ! -d $workingdir ]]; then mkdir $workingdir; fi

		if [[ $resume == "Y" ]]; then
			cd $workingdir
			message_cmd_log "----Resuming pipeline"
            pipeline_full_cmd="/home/ubuntu/tools/nextflow run /home/ubuntu/workflows/AR_Workflow/tools/phoenix/main.nf -resume \
            -profile docker -entry VALAR --max_memory 7.GB --max_cpus 4 \
            --input $samplesheet \
            --kraken2db /home/ubuntu/workflows/SARS_CoV_2_Workflow/refs/kraken2db/ \
            --outdir $pipeline_batch_dir \
            --projectID $project_name_full"

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
				mv `ls $tmp_dir/${shortID}*/*R1*fastq.gz | head -1` $fastq_batch_dir
				mv `ls $tmp_dir/${shortID}*/*R2*fastq.gz | head -1` $fastq_batch_dir

				# remove downloaded tmp dir
				rm -r --force $tmp_dir/${shortID}*
			done

			# rename all ID files
			## batch manifests
			cleanmanifests $batch_manifest
			cleanmanifests $samplesheet
			cleanmanifests $log_dir/manifests/sample_ids.txt
			
			## fastq files renamed
			for f in $fastq_batch_dir/*; do
				new=`echo $f | sed "s/_S[0-9].*_L001//g" | sed "s/_001//g" | sed "s/[_-]ASTVAL//g" |  sed "s/[_-]AST//g" | sed "s/-$project_name_full//g" | sed "s/-$project_name//g" | sed "s/-OH//g" | sed "s/_R/.R/g"`
				if [[ $new != $f ]]; then mv $f $new; fi
			done

			#log
			message_cmd_log "------ANALYSIS"
			echo "-------Starting time: `date`" >> $pipeline_log
			echo "-------Starting space: `df . | sed -n '2 p' | awk '{print $5}'`" >> $pipeline_log
			
			#run NEXTLFOW
			cd $workingdir
			pipeline_full_cmd="/home/ubuntu/tools/nextflow run /home/ubuntu/workflows/AR_Workflow/tools/phoenix/main.nf \
            -profile docker -entry VALAR --max_memory 7.GB --max_cpus 4 \
            --input $samplesheet \
            --kraken2db /home/ubuntu/workflows/SARS_CoV_2_Workflow/refs/kraken2db/ \
            --outdir $pipeline_batch_dir \
            --projectID $project_name_full"
            
            echo "$pipeline_full_cmd"
			$pipeline_full_cmd
		fi

		#############################################################################################
		# Reporting
		#############################################################################################	
		# grab raw gamma files
        for f in $pipeline_batch_dir/*/gamma_ar/*.gamma; do
            cp $f $gamma_dir
        done

        # grab raw kraken2 files
        for f in $pipeline_batch_dir/*/kraken*/*wtasmbld.summary*; do
	        cp $f $kraken2_dir
        done

		# cp pipeline file
		cp  $pipeline_batch_dir/Phoenix_Summary.tsv $analysis_dir/intermed/$batch_id.tsv

		# cp multiqc files
		for f in $pipeline_batch_dir/*/qc_stats/*; do
			cp $f $mqc_dir
		done

		#############################################################################################
		# CLEANUP
		#############################################################################################	
		#remove intermediate files
	    if [[ $flag_cleaning == "Y" ]]; then
            sudo rm -r --force $pipeline_batch_dir
		    sudo rm -r --force $fastq_batch_dir
        fi
	done
fi

if [[ $flag_gamma == "Y" ]]; then
	# prep file
	if [ -f $gamma_results ]; then rm $gamma_results; fi

	# for each file print name of file and all genes
	for f in $gamma_dir/*.gamma; do
		id=`echo $f | cut -f9 -d"/" | sed "s/_ResGANNCBI_20230517_srst2.gamma//g"`
		line=`awk '{print $1}' $f | sort | uniq | awk '{printf "%s%s",sep,$1; sep=","} END{print ""}' | sed "s/,Gene//g"`
		echo "$id,$line" >> $gamma_results
	done

	# cleanup gamma
	sed -i "s/-//g" $gamma_results

	# review
	head $gamma_results
fi

if [[ $flag_kraken == "Y" ]]; then
	# prep file
	if [ -f $species_results ]; then rm $species_results; fi

	for f in $kraken2_dir/*; do
		s=`cat $f | grep "S" | awk 'NR==1{print $6" "$7}'`
		n=`echo $f | cut -f9 -d"/" | cut -f1 -d"."`
		echo "$n,$s" >> $species_results
	done

	# review
	head $species_results
fi

if [[ $flag_mqc == "Y" ]]; then
	# run multiQC
	## -d -dd 1 adds dir name to sample name
	multiqc -f -v \
	-c $multiqc_config \
	$mqc_dir \
	$kraken2_dir \
	-o $analysis_dir/qc/ 2>&1 | tee -a $multiqc_log
fi