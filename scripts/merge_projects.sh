#!/bin/bash
#########################################################
# ARGS
########################################################
project_name_list=$1
merge_id=$2

#########################################################
# Pipeline controls
########################################################
project_output=/home/ubuntu/output/$merge_id

#########################################################
# Files, dirs
########################################################
intermed_dir=$project_output/analysis/intermed
qc_dir=$project_output/analysis/qc
report_dir=$project_output/analysis/report
tree_dir=$project_output/analysis/intermed/tree
input_dir=$project_output/analysis/intermed/tree/input_dir
val_dir=$project_output/analysis/intermed/val
merged_results=$intermed_dir/pipeline_results.tsv
final_results=$project_output/analysis/reports/final_report.csv

#########################################################
# Workflow
########################################################
# create project list
IFS=',' read -r -a project_list <<< "$project_name_list"

# prepare the projects
for pid in ${project_list[@]}; do
    echo "--processing $pid"
    
    # set dirs and files
    tmp_output="/home/ubuntu/output/$pid"
    tmp_intermed="$tmp_output/analysis/intermed"

    tmp_results=$tmp_intermed/pipeline_results.tsv
    tmp_qcdir="$tmp_output/analysis/qc"
    tmp_treedir="$tmp_intermed/tree"
    tmp_input_dir=$tmp_treedir
    tmp_val_dir="$tmp_intermed/val"
    tmp_final=$tmp_report_dir/final_report.csv

    ## check if there is an input dir
	if [[ -f $tmp_input_dir.tar.gz ]]; then
		tar -zxf $tmp_input_dir.tar.gz --directory $input_dir
	fi

    # cp each file to joint dir
	cat $tmp_results >> $merged_results
    cat $tmp_final >> $final_results

	cp -r $tmp_qcdir/* $qc_dir
	cp -r $tmp_treedir/* $tree_dir
    cp -r $tmp_report_dir/* $report_dir
    cp -r $tmp_val_dir/* $val_dir
done