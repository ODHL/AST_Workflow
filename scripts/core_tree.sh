#########################################################
# ARGS
#########################################################
output_dir=$1
unique_id=$2
pipeline_config=$3
pipeline_log=$4
resume=$5
subworkflow=$6

#########################################################
# Pipeline controls
########################################################
flag_prep="N"
flag_analysis="N"
flag_report="N"
flag_cleanup="N"

if [[ $subworkflow == "PREP" ]]; then
	flag_prep="Y"
elif [[ $subworkflow == "ANALYZE" ]]; then
	flag_analysis="Y"
elif [[ $subworkflow == "POST" ]]; then
	flag_report="Y"
elif [[ $subworkflow == "ALL" ]]; then
	flag_prep="Y"
	flag_analysis="Y"
	flag_report="Y"
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
tmp_dir=$output_dir/tmp
analysis_dir=$output_dir/analysis
manifest_dir=$log_dir/manifests
pipeline_dir=$output_dir/tmp/pipeline/tree

intermed_dir=$output_dir/analysis/intermed
trimm_dir=$tmp_dir/rawdata/trimmed
tree_dir=$tmp_dir/tree
gff_dir=$tmp_dir/gff

# set variables
ODH_version=$config_ODH_version
phoenix_version=$config_phoenix_version
dryad_version=$config_dryad_version

# set files
samplesheet=$log_dir/manifests/samplesheet_gff.csv	
merged_tree=$intermed_dir/core_genome.tree
merged_roary=$intermed_dir/core_genome_statistics.txt
merged_snp=$intermed_dir/snp_distance_matrix.tsv

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
analysis_cmd_trailing=$config_tree_cmd_trailing

#############################################################################################
# Analysis
#############################################################################################
if [[ $flag_prep == "Y" ]]; then
	message_cmd_log "------------------------------------------------------------------------"
	message_cmd_log "--Prepping files"
	message_cmd_log "------------------------------------------------------------------------"

	# create samplesheet
	if [[ -f $samplesheet ]]; then rm $samplesheet; fi
	echo "sample,gff,fq1,fq2" > $samplesheet

	# create sample log
	if [[ -f sample_list.txt ]]; then rm sample_list.txt; fi
	for f in $gff_dir/*gff; do
		filename="${f##*/}"
		sample_id=`echo $filename | cut -f1 -d"."`
		echo $sample_id >> sample_list.txt
	done

	# read text file
	IFS=$'\n' read -d '' -r -a sample_list < sample_list.txt

	## create samplesheet
	## move fq's to CFSAN dir
	for sample_id in ${sample_list[@]}; do
		# set output dir
		fq_dest="$tree_dir/input_dir/$sample_id"
		if [[ ! -d $fq_dest ]]; then mkdir -p $fq_dest; fi

		# set files
		gff="$gff_dir/$sample_id.gff"
		fq1="${sample_id}_1.trim.fastq.gz"
		fq2="${sample_id}_2.trim.fastq.gz"

		# move files to subdir
		handle_fq $fq_dest $fq1 $trimm_dir
		handle_fq $fq_dest $fq2 $trimm_dir

		# add to the samplesheet
        echo "${sample_id},$gff,$fq1,$fq2" >> $samplesheet
	done

	rm sample_list.txt
fi

if [[ $flag_analysis == "Y" ]]; then
	#log
	message_cmd_log "------------------------------------------------------------------------"
	message_cmd_log "--- CONFIG INFORMATION ---"
	message_cmd_log "Analysis date: `date`"
	message_cmd_log "Pipeline version: $ODH_version"
	message_cmd_log "------------------------------------------------------------------------"

	message_cmd_log "------------------------------------------------------------------------"
	message_cmd_log "--Creating tree:"
	message_cmd_log "------------------------------------------------------------------------"

    # Run pipeline
    cd $pipeline_dir
	pipeline_full_cmd="$analysis_cmd $analysis_cmd_trailing --input $samplesheet --outdir $pipeline_dir --treedir $tree_dir/input_dir --projectID $unique_id --kraken2db $config_kraken2_db"
	echo "$pipeline_full_cmd"
	$pipeline_full_cmd

	# log
	message_cmd_log "-------Ending time: `date`"
	message_cmd_log "-------Ending space: `df . | sed -n '2 p' | awk '{print $5}'`"
fi

if [[ $flag_report == "Y" ]]; then
	message_cmd_log "------------------------------------------------------------------------"
	message_cmd_log "--TREE REPORT"
	message_cmd_log "------------------------------------------------------------------------"
	
	#############################################################################################
	# Move reports
	#############################################################################################	
	cp $pipeline_dir/ROARY/core_genome_statistics.txt $merged_roary
	cp $pipeline_dir/TREE/core_genome.tree $merged_tree
	cp $pipeline_dir/CFSAN/snp_distance_matrix.tsv $merged_snp
	cp $pipeline_dir/pipeline_info/* $log_dir/pipeline

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