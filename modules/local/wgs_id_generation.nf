process WGS_ID_GENERATION {
    tag "WGS_ID_GENERATION"
    label 'process_low'

    input:
    path(final_report)                          // Phoenix_Output_Report.tsv
    path(wgs_master)                            // wgs_db_master.tsv
    path(wgs_local)                             // wgs_db_local.tsv
    val(projectID)                              // OH-62623

    output:
    path "*wgs_db_local*"                           , emit: wgs_local
    path "*cache_wgs_db_local*"                     , emit: wgs_cache_local
    path "*cache_wgs_db_master*"                    , emit: wgs_cache_master

    script:
    """
    # read in final report
    IFS=\$'\n' read -d '\t' -r -a sample_list < $final_report

    # create cache of local
    cached_db="${today}_cache_wgs_db_local.csv"
    cp wgs_db_local.csv $cached_db

    # for each sample, check ID file
    while read sampleID; do
        echo $sampleID
        # check if sample already has an ID
        check=`cat $cached_db | grep "$sampleID"`
        echo "$check"
        # if the check passes, add new ID
        if [[ $check == "" ]]; then
            # determine final ID assigned
            # WGSID,CGR_ID,projectID,DATE_ASSIGNED
            # YYYY-GZ-0001
            final_ID=`tail -n1 $cached_db | awk -F"," '{print $1}' | cut -f3 -d"-"`
            new_id=$(( final_ID + 1 ))

            # add sample with new ID to list
            add_line="2023-GZ-$new_id,$sampleID,OH-VH00648-230526_AST,$today"
            echo $add_line >> $cached_db
        else
            echo "The sample has already been added to the WGS Database"
            echo $check
        fi
    done < sampleids.txt

    # create new copy
    cp wgs_db_master.csv ${today}_cache_wgs_db_master.csv
    cp $cached_db wgs_db_master.csv
    """
}
