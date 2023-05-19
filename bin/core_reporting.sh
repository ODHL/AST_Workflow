#########################################################
# ARGS
#########################################################
output_dir=$1
project_name_full=$2
pipeline_config=$3

##########################################################
# Eval, source
#########################################################
source $(dirname "$0")/functions.sh
eval $(parse_yaml ${pipeline_config} "config_")

##########################################################
# Set flags
#########################################################
flag_prep="Y"
flag_ar="N"
flag_qc="N"

#########################################################
# Set dirs, files, args
#########################################################
# set variables
project_name_full=$(echo $project_id | sed 's:/*$::')
project_name=$(echo $project_id | cut -f1 -d "_" | cut -f1 -d " ")

# set dirs
log_dir=$output_dir/logs
pipeline_log="$log_dir/pipeline_log.txt"

qc_dir=$output_dir/qc
tmp_dir=$output_dir/tmp

analysis_dir=$output_dir/analysis
intermed_dir=$analysis_dir/intermed
reports_dir=$analysis_dir/reports
pipeline_dir=$output_dir/phoenix

# set files
sample_manifest="$log_dir/ar_report_manifest.txt"
snpmatrix="$intermed_dir/snp_distance_matrix.tsv"
tree="$intermed_dir/core_genome.tree"
cgstats="$intermed_dir/core_genome_statistics.txt"
artable="$intermed_dir/ar_predictions.tsv"

# remove old files
file_list=(sample_manifest snpmatrix tree cgstats artable)
for f in "${file_list[@]}"; do if [[ -f $f ]]; then sudo rm $f; fi; done

#############################################################################################
# LOG INFO TO CONFIG
#############################################################################################
message_cmd_log "------------------------------------------------------------------------"
message_cmd_log "--- RUNNING REPORT ---"
echo "---Starting time: `date`" >> $pipeline_log
echo "---Starting space: `df . | sed -n '2 p' | awk '{print $5}'`" >> $pipeline_log

#############################################################################################
# Create final reports
#############################################################################################
# prep each of the report inputs
if [[ $flag_prep == "Y" ]]; then
    echo "--PREPPING Report"
    # determine number of batches
	batch_count=`ls $log_dir/batch* | wc -l`
	batch_min=1

    if [[ -f $sample_manifest ]]; then rm $sample_manifest; fi
    echo -e "SampleID\tSpeciesID\tMLST\tResistanceGenes" > $sample_manifest     
    echo -e "SampleID\tGene\tCoverage\tIdentity" > $artable

	#for each batch
	for (( batch_id=$batch_min; batch_id<=$batch_count; batch_id++ )); do
        echo "--processing batch $batch_id"
        # set output batch dir
        pipeline_batch_dir=$pipeline_dir/batch_$batch_id
        tmp_batch_dir=$tmp_dir/batch_$batch_id
        if [[ ! -d $tmp_batch_dir ]]; then mkdir $tmp_batch_dir; fi
        artable_int=$intermed_dir/amr_genes_$batch_id.tsv
        if [[ -f $artable_int ]]; then sudo rm $artable_int; fi
        echo -e "Protein_identifier\tContig_id\tStart\tStop\tStrand\tGene_symbol\tSequence_name\tScope\tElement_type\tElement_subtype\tClass\tSubclass\tMethod\tTarget_length\tReference_sequence_length\t%_Coverage_of_reference_sequence\t%_Identity_to_reference_sequence\tAlignment_length\tAccession_of_closest_sequence\tName_of_closest_sequence\tHMM_id\tHMM_description" > $artable_int

        #############################################
        # copy snpmatrix
        cp $pipeline_batch_dir/report/snp_distance_matrix.tsv $intermed_dir/snp_distance_matrix_batch_$batch_id.tsv

        ## push to output
        cat $intermed_dir/snp_distance_matrix_batch_$batch_id.tsv >> $snpmatrix

        # ##############################################
        # copy tree
        cp $pipeline_batch_dir/report/snp.tree $intermed_dir/core_genome_batch_$batch_id.tree

        ## push to output
        cat $intermed_dir/core_genome_batch_$batch_id.tree >> $tree

        # ##############################################
        # copy cgstats
        cp $pipeline_batch_dir/report/core_genome_statistics.txt $intermed_dir/core_genome_statistics_$batch_id.txt

        ## push to output
        cat $intermed_dir/core_genome_statistics_$batch_id.txt >> $cgstats

        ##############################################
        # prep artable
        tail -n +2 $pipeline_batch_dir/Analysis_Output_Report.tsv > $tmp_batch_dir/artable.tsv
        sample_list=`awk -F"\t" '{print $1}' $tmp_batch_dir/artable.tsv`

        for sid in ${sample_list[@]}; do
            echo "---processing $sid"
            tail -n +2 $pipeline_batch_dir/$sid/AMRFinder/${sid}_all_genes.tsv >> $artable_int
            awk -F"\t" -v sid=$sid '{print sid"\t"$6"\t"$16"\t"$17}' $artable_int >> $artable
        done
        ##############################################
        # prep samplemanifest
        tail -n +2 $pipeline_batch_dir/Analysis_Output_Report.tsv > $tmp_batch_dir/report.tsv
        awk -F"\t" '{print $1"\t"$9"\t"$14"\t"$18}' $tmp_batch_dir/report.tsv >> $sample_manifest
        
        ##############################################
        # move required files to tmp report directory
        sudo rm -r $tmp_report_dir/*
        cp $snpmatrix $tmp_report_dir
        cp $tree $tmp_report_dir
        cp $cgstats $tmp_report_dir
        cp $artable $tmp_report_dir
        cp $sample_manifest $tmp_report_dir

    done
fi

# run docker with ar-report generator
if [[ $flag_ar == "Y" ]]; then
    echo "-Running report"
    # run docker
    cd ~
    docker run -it --mount type=bind,source="$(pwd)"/tools/ar_report_generator/,target=/mnt/ar_rep quay.io/wslh-bioinformatics/ar-report
    
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

    cd ../mnt/ar_rep
    ./render_report.R \
        'test_dryad_github' \
        'Dr. Samantha Chill' \
        /mnt/ar_rep/report/ar_report_manifest.tsv \
        ar_report_config.yaml \
        /mnt/ar_rep/report \
        --snpmatrix /mnt/ar_rep/report/snp_distance_matrix.tsv \
        --cgstats /mnt/ar_rep/report/core_genome_statistics.txt \
        --artable /mnt/ar_rep/report/ar_predictions.tsv \
        --tree /mnt/ar_rep/report/core_genome.tree

    # end docker
    docker stop
fi

#create fragment plot
if [[ $flag_qc == "N" ]]; then
    python scripts/fragment_plots.py $merged_fragment $fragement_plot
fi

# echo "Ending time: `date`" >> $pipeline_log
# echo "Ending space: `df . | sed -n '2 p' | awk '{print $5}'`" >> $pipeline_log
# message_cmd_log "--- COMPLETE REPORT ---"
# message_cmd_log "------------------------------------------------------------------------"