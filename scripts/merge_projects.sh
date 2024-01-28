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
qc_dir=$project_output/analysis/intermed/qc
tree_dir=$project_output/analysis/intermed/tree
merged_results=$intermed_dir/pipeline_results_clean.tsv

#########################################################
# Workflow
########################################################
# create project list
IFS=',' read -r -a project_list <<< "$project_name_list"

# prepare the projects
for pid in ${project_list[@]}; do
    
    # set dirs and files
    tmp_output="/home/ubuntu/output/pid"
    tmp_intermed="$tmp_output/analysis/intermed"
    tmp_qcdir="$tmp_output/analysis/qc"
    tmp_treedir="$tmp_intermed/tree"
    tmp_results=$tmp_intermed/pipeline_results_clean.tsv

    # cp each file to joint dir
	cat $tmp_results >> $merged_results
	cp $tmp_qcdir $qc_dir
	cp $tmp_treedir $tree_dir
done