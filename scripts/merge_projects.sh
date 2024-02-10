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

# create merged result
if [[ -f $merged_results ]]; then rm $merged_results; fi
touch $merged_results    
if [[ -f $final_results ]]; then rm $final_results; fi
touch $final_results    

# prepare the projects
for pid in ${project_list[@]}; do
    echo "--processing $pid"
    
    # set dirs and files
    proj_output="/home/ubuntu/output/$pid"
    proj_intermed="$proj_output/analysis/intermed"

    proj_results=$proj_intermed/pipeline_results.tsv
    proj_final=$proj_output/analysis/reports/final_results.tsv
    proj_qcdir="$proj_output/analysis/qc"
    proj_treedir="$proj_intermed/tree"
    proj_input_dir=$proj_treedir
    proj_val_dir="$proj_intermed/val"

    ## check if there is an input dir
    ## if there is, make sure that it's untarred
	if [[ -f $proj_input_dir.tar.gz ]]; then
		tar -zxf $proj_input_dir.tar.gz --directory $input_dir
	fi

    # check files
    file_list=($proj_results $proj_final)
    for file_check in ${file_list[@]} ; do
        if [[ ! -f $file_check ]]; then
            echo "----MISSING FILE: $file_check"
            exit
        else
            echo "----PASS"
        fi
    done

    dir_list=($proj_qcdir $proj_treedir $proj_val_dir)
    for dir_check in ${dir_list[@]} ; do
        if [[ ! -d $dir_list ]]; then
            echo "----MISSING DIR: $dir_list"
            exit
        else
            echo "----PASS"
        fi
    done
    # cp each file to joint dir
	cat $proj_results >> $merged_results
    cat $proj_final >> $final_results
	cp -r $proj_qcdir/* $qc_dir
	cp -r $proj_treedir/* $tree_dir
    cp -r $proj_val_dir/* $val_dir
done