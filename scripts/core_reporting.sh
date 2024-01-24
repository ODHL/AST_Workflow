# bash bin/core_reporting.sh /home/ubuntu/output/ast_run1 BASIC
# bash bin/core_reporting.sh /home/ubuntu/output/ast_run2 BASIC

#########################################################
# ARGS
#########################################################
final_dir=$1
report_type=$2

##########################################################
# Set flags
#########################################################
flag_basic="N"
flag_outbreak="N"
flag_novel="N"
flag_regional="N"
flag_time="N"

if [[ $report_type == "BASIC" ]]; then
    flag_basic="Y"
elif [[ $report_type == "OUTBREAK" ]]; then
    flag_outbreak="Y"
elif [[ $report_type == "NOVEL" ]]; then
    flag_novel="Y"
elif [[ $report_type == "REGIONAL" ]]; then
    flag_regional="Y"
elif [[ $report_type == "TIME" ]]; then
    flag_time="Y"
else
    echo "Check report type selected: $report_type"
    echo "Must be BASIC OUTBREAK NOVEL REGIONAL TIME"
    exit
fi

# Set date
today=`date +%Y%m%d`

# set project file
project_file="$final_dir/project_list.tsv"

# set script dir
# script_dir="/home/ubuntu/workflows/AST_Workflow/bin"
# assets_dir="/home/ubuntu/workflows/AST_Workflow/assets"

# set processing dir; output
# ar_generator_dir="/home/ubuntu/tools/ar_report_generator"
process_dir_files="/home/ubuntu/tools/ar_report_generator/processing_files"
# if [[ -d $process_dir_files ]]; then sudo rm -r $process_dir_files; fi
# process_dir_out="/home/ubuntu/tools/ar_report_generator/processing_output"
# if [[ -d $process_dir_out ]]; then sudo rm -r $process_dir_out; fi
# mkdir $process_dir_files; mkdir $process_dir_out

# set wgs
wgs_dir="$assets_dir/wgs_db"
wgs_ids="$wgs_dir/wgs_db_master.csv"

##########################################################
# Run each project
#########################################################
# read in project list
IFS=$'\n' read -d '' -r -a project_list < $project_file

# set report
report_dir="$final_dir/${today}_${report_type}"
if [[ ! -d $report_dir ]]; then mkdir -p $report_dir; else rm -r $report_dir;  mkdir -p $report_dir; fi

# create reports
predictions_tsv="$report_dir/ar_predictions.csv"
manifest_csv="$report_dir/final.tsv"

wgs_tsv="$report_dir/wgs_manifest.tsv"
wgs_tmp="$report_dir/wgs_tmp.tsv"
prediction_ids_tsv="$report_dir/prediction_ids.tsv"

# prep final files
echo -e "Sample \tGene \tCoverage \tIdentity" > $predictions_tsv
echo -e ""Lab ID"",""WGS ID"",""Project ID"",""Date Collected"",""Organism"",""Specimen Source"",""Resistance Genes"",""Estimated_Coverage"",""Taxa_Confidence"",""Auto_QC_Outcome"",""Auto_QC_Failure_Reason"",""Comments"" > $manifest_csv

# create files for basic report
for proj_dir in ${project_list[@]}; do
    output_dir="/home/ubuntu/$proj_dir"

    echo "--Processing $output_dir"
    
    # check files exist
    amr_reports="$output_dir/*/AMRFinder/*_all_genes.tsv"
    phoenix_report="$output_dir/Phoenix_Output_Report.tsv"
    snpmatrix="$output_dir/DRYAD/snp_distance_matrix.tsv"
    tree="$output_dir/TREE.out.genome_tree"

    file_list=($amr_reports $phoenix_report $snpmatrix $tree)
    for f in ${file_list[@]}; do
        if [[ ! -f $f ]]; then
            echo "Missing FILE required for basic report: $f"
            exit
        fi
    done

    # create predictions file
    awk '{print FILENAME"\t" $0}' $amr_reports | \
    awk -F"\t" '{print $1"\t"$7"\t"$17"\t"$18}' | sed -s "s/_all_genes.tsv//g" > ${predictions_tsv}tmp
    ## pull the sampleID from the file name
    awk '{sub(/.*\//,"",$1)}1' ${predictions_tsv}tmp > ${predictions_tsv}tmp2
    ## push to final file
    cat ${predictions_tsv}tmp2 | grep -v "_Coverage_of_reference_sequence" >> $predictions_tsv
    sed -i "s/ /,/g" $predictions_tsv
    sed -i "s/\t//g" $predictions_tsv

    # Prep wgs manifest
    tail -n +2 $phoenix_report > ${wgs_tsv}
    sed -i "s/,/;/g" ${wgs_tsv}
    sed -i "s/\t/,/g" ${wgs_tsv}

    # final manifest
    awk -F"," '{print $2","$1","$3}' $wgs_ids > $wgs_tmp
    join <(sort $wgs_tsv) <(sort $wgs_tmp) -t $',' > $prediction_ids_tsv
    awk -F"," '{print $1","$24","$25",,"$9",,"$19","$4","$10","$2","$23","}' $prediction_ids_tsv >> $manifest_csv
done

# move files depending on reports
touch $report_dir/snp_distance_matrix.tsv
touch $report_dir/core_genome.tree
touch $report_dir/core_genome_statistics.txt

for proj_dir in ${project_list[@]}; do
    output_dir="/home/ubuntu/$proj_dir"

    cat $output_dir/DRYAD/snp_distance_matrix.tsv >> $report_dir/tmp_snp_distance_matrix.tsv
    cat $output_dir/DRYAD/core_genome.tree >> $report_dir/tmp_core_genome.tree
    cat $output_dir/DRYAD/core_genome_statistics.txt >> $report_dir/tmp_core_genome_statistics.txt
done

cp $intermed_dir/snp_distance_matrix.tsv $report_dir
cp $intermed_dir/tmp_core_genome.tree | uniq > $report_dir/core_genome.tree
cp $intermed_dir/tmp_core_genome_statistics.txt | uniq > $report_dir/core_genome_statistics.txt

# run basic report
## includes: QC, SUMMARY | HEATMAP, TREE
if [[ $flag_basic == "Y" ]]; then
    # move files
    ## project files
    cp $manifest_csv $process_dir_files/manifest.csv
    cp $report_dir/snp_distance_matrix.tsv $process_dir_files # will create heatmap
    cp $report_dir/core_genome.tree $process_dir_files # will create tree
    cp $report_dir/core_genome_statistics.txt $process_dir_files # will create tree
    ## scripts files
    cp $script_dir/render_report.R $process_dir_files
    sudo rm -f $ar_generator_dir/*ar-report.html
    cp $script_dir/ar_report_generator_html.Rmd $ar_generator_dir
    cp $assets_dir/ar_report_config.yaml $process_dir_files

    # run report
    # inputs: date \ name \ manifest file \ ar_config file \ 
    echo "---Running NOVEL report"

    # prep report
    echo
    echo "cd ../mnt/ar_rep; ./render_report.R $today 'Dr. Samantha Chill' \
    processing_files/manifest.csv processing_files/ar_report_config.yaml processing_output/ \
    --snpmatrix processing_files/snp_distance_matrix.tsv --tree processing_files/core_genome.tree \
    --cgstats processing_files/core_genome_statistics.txt"
    echo

    # run docker
    cd ~
    docker run -it --mount type=bind,source="$(pwd)"/tools/ar_report_generator/,target=/mnt/ar_rep quay.io/wslh-bioinformatics/ar-report
elif [[ $flag_oubreak == "Y" ]]; then
    # move files
    ## project files
    cp $manifest_csv $process_dir_files/manifest.csv
    cp $predictions_tsv $process_dir_files/predictions.csv # will create gene summary
    cp $report_dir/snp_distance_matrix.tsv $process_dir_files # will create heatmap
    cp $report_dir/core_genome.tree $process_dir_files # will create tree
    cp $report_dir/core_genome_statistics.txt $process_dir_files # will create tree
    ## scripts files
    cp $script_dir/render_report.R $process_dir_files
    sudo rm -f $ar_generator_dir/*ar-report.html
    cp $script_dir/ar_report_generator_html.Rmd $ar_generator_dir
    cp $assets_dir/ar_report_config.yaml $process_dir_files

    # run report
    # inputs: date \ name \ manifest file \ ar_config file \ 
    echo "---Running OUTBREAK report"

    # prep report
    echo
    echo "cd ../mnt/ar_rep; ./render_report.R $today 'Dr. Samantha Chill' \
    processing_files/manifest.csv processing_files/ar_report_config.yaml processing_output/ \
    --snpmatrix processing_files/snp_distance_matrix.tsv --tree processing_files/core_genome.tree \
    --cgstats processing_files/core_genome_statistics.txt --artable processing_files/predictions.csv"
    echo

    # run docker
    cd ~
    docker run -it --mount type=bind,source="$(pwd)"/tools/ar_report_generator/,target=/mnt/ar_rep quay.io/wslh-bioinformatics/ar-report
    
fi

# # run basic report
# if [[ $flag_complete == "Y" ]]; then
#     # run report
#     # inputs: date \ name \ manifest file \ ar_config file \ 
#     Rscript /home/ubuntu/workflows/AST_Workflow/bin/render_report.R \\
#     \$today \\
#     'Dr. Samantha Chill' \\
#     $manifest_csv \\
#     ${ar_config} \\
#     $PWD/ \\
#     --snpmatrix ${snpmatrix} \\
#     --tree $PWD/${tree} \\
#     --cgstats ${core_genome} \\
#     --artable ar_predictions.tsv \\
#     --freq $PWD/${pangenome_frequency} \\
#     --matrix $PWD/${pangenome_matrix} \\
#     --pie $PWD/${pangenome_pie} \\
#     --reportType "standard"
# fi

# # run report
    # cd ../mnt/ar_report_generator
    # ./render_report.R \
    #     --projectname $project_name_full \
    #     --username 'Dr. Samantha Chill' \
    #     --sampletable $sample_manifest \
    #     --config ar_report_config.yaml \
    #     --out_dir $tmp_dir \
    #     --snpmatrix $tmp_dir/snp_distance_matrix.tsv \
    #     --tree $tmp_dir/core_genome.tree \
    #     --cgstats $tmp_dir/core_genome_statistics.txt \
    #     --artable $tmp_dir/ar_predictions.tsv
