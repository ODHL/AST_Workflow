#########################################################
# ARGS
#########################################################
subworkflow=$1
project_name_full=$2
output_dir=$3
pipeline_config=$4

#########################################################
# Pipeline controls
########################################################
# set flags
flag_report="N"
flag_mqc="N"

if [[ $flag == "REPORT" ]]; then
	flag_report="Y"
elif [[ $flag == "MQC" ]]; then
	flag_mqc="Y"
elif [[ $flag == "ALL" ]]; then
    flag_report="Y"
    flag_mqc="Y"
fi

#########################################################
# Set dirs, files, args
#########################################################
# pipeline raw output
pipeline_dir=$output_dir/pipeline

# logdir
log_dir=$output_dir/logs

## final analysis output
analysis_dir=$output_dir/analysis

# qc dir
mqc_dir=$analysis_dir/qc/data

# results files
date_check="240125"
gamma_results="$analysis_dir/intermed/gamma_results_$date_check.csv"
kraken_results="$analysis_dir/intermed/kraken_results_$date_check.txt"
val_results="$analysis_dir/reports/val_results_$date_check.txt"

multiqc_config="$output_dir/logs/config/config_multiqc.yaml"
multiqc_log="$output_dir/logs/log_multiqc.txt"

# set project shorthand
project_name=$(echo $project_name_full | cut -f1 -d "_" | cut -f1 -d " ")
##########################################################
# Eval, source
#########################################################
source /home/ubuntu/workflows/AR_Workflow/scripts/core_functions.sh
eval $(parse_yaml ${pipeline_config} "config_")

if [[ $flag_report == "Y" ]]; then
	# prep file
	if [ -f $gamma_results ]; then rm $gamma_results; fi

	# for each file print name of file and all genes
	for f in $gamma_dir/*.gamma; do
		id=`echo $f | cut -f9 -d"/" | sed "s/_ResGANNCBI_20230517_srst2.gamma//g"`
		line=`awk '{print $1}' $f | sort | uniq | awk '{printf "%s%s",sep,$1; sep=","} END{print ""}' | sed "s/,Gene//g"`
		echo "$id,$line" >> $gamma_results
	done

	# get the taxonomic ID
	awk '{ print $1","$2" }' $kraken_results

	# cleanup gamma
	sed -i "s/-//g" $gamma_results

	# review
	head $gamma_results
	echo
	head $kraken_results

	# merge
	join <(sort $kraken_results) <(sort $gamma_results) -t $',' > $val_results
fi

if [[ $flag_mqc == "Y" ]]; then
	# run multiQC
	## -d -dd 1 adds dir name to sample name
	multiqc -f -v \
	-c $multiqc_config \
	$mqc_dir \
	$val_dir \
	-o $analysis_dir/qc/ 2>&1 | tee -a $multiqc_log
fi