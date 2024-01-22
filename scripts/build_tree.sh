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
elif [[ $subworkflow == "REPORT" ]]; then
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
intermed_dir=$output_dir/analysis/intermed
tree_dir=$output_dir/analysis/intermed/tree

pipeline_dir=$output_dir/pipeline
workingdir=$pipeline_dir/working
prokka_merged_dir=$pipeline_dir/prokka
if [[ ! -d $workingdir ]]; then mkdir $workingdir; fi
if [[ ! -d $prokka_merged_dir ]]; then mkdir $prokka_merged_dir; fi

# set variables
ODH_version=$config_ODH_version
phoenix_version=$config_phoenix_version
dryad_version=$config_dryad_version

# set files
merged_tree=$intermed_dir/tree/core_genome.tree
merged_roary=$intermed_dir/tree/core_genome_statistics.txt
samplesheet=$log_dir/manifests/samplesheet_gff.csv	
	
# set cmd and log
if [[ $resume == "Y" ]]; then
	message_cmd_log "----Resuming pipeline at $workingdir"
    echo "-------Resuming time: `date`" >> $pipeline_log
	echo "-------Resuming space: `df . | sed -n '2 p' | awk '{print $5}'`" >> $pipeline_log
    analysis_cmd=`echo $config_analysis_cmd -resume`
else
	message_cmd_log "----Starting pipeline at $workingdir"
	echo "-------Starting time: `date`" >> $pipeline_log
	echo "-------Starting space: `df . | sed -n '2 p' | awk '{print $5}'`" >> $pipeline_log
    analysis_cmd=$config_analysis_cmd
fi
analysis_cmd_trailing=$config_tree_cmd_trailing

#############################################################################################
# LOG INFO TO CONFIG
#############################################################################################
message_cmd_log "--- CONFIG INFORMATION ---"
message_cmd_log "Analysis date: `date`"
message_cmd_log "Pipeline version: $ODH_version"

#############################################################################################
# Analysis
#############################################################################################
if [[ $flag_prep == "Y" ]]; then
	# create samplesheet
	if [[ -f $samplesheet ]]; then rm $samplesheet; fi
	echo "sample,gff,fq1,fq2" > $samplesheet

	message_cmd_log "--Prepping GFF files"
	# create sample log
	if [[ -f sample_list.txt ]]; then rm sample_list.txt; fi
	for f in $tree_dir/*gff; do
		filename="${f##*/}"
		sample_id=`echo $filename | cut -f1 -d"."`
		echo $sample_id >> sample_list.txt
	done
	IFS=$'\n' read -d '' -r -a sample_list < sample_list.txt

	for f in ${sample_list[@]}; do
		gff="$tree_dir/$sample_id.gff"
		fq1="$tree_dir/${sample_id}_1.trim.fastq.gz"
		fq2="$tree_dir/${sample_id}_2.trim.fastq.gz"

		# add to the samplesheet
        echo "${sample_id},$gff,$fq1,$fq2" >> $samplesheet
	done
	cat $samplesheet
fi

if [[ $flag_analysis == "Y" ]]; then
	#log
	message_cmd_log "--Creating tree:"

    # Run pipeline
    cd $workingdir
	pipeline_full_cmd="$analysis_cmd $analysis_cmd_trailing --input $samplesheet --outdir $pipeline_dir --projectID $unique_id"
	echo "$pipeline_full_cmd"
	$pipeline_full_cmd

	# log
	echo "-------Ending time: `date`" >> $pipeline_log
	echo "-------Ending space: `df . | sed -n '2 p' | awk '{print $5}'`" >> $pipeline_log

	#############################################################################################
	# CLEANUP
	#############################################################################################	
	#remove intermediate files
	if [[ $flag_cleanup == "Y" ]]; then
		sudo rm -r --force $pipeline_dir
	fi
fi

if [[ $flag_report == "Y" ]]; then
	cp $pipeline_batch_dir/ROARY/core_genome_statistics.txt >> $merged_roary
	cat $pipeline_batch_dir/TREE/core_genome.tree >> $merged_tree
fi