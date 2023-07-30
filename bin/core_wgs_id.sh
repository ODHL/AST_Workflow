# bash bin/core_wgs_id.sh /home/ubuntu/output/OH-VH00648-230526/pipeline/batch_1 OH-VH00648-230526
#########################################################
# ARGS
#########################################################
output_dir=$1
project_id=$2

##########################################################
# Set files, dir
#########################################################
final_report="$output_dir/Phoenix_Output_Report.tsv"
wgs_dir="/home/ubuntu/workflows/AST_Workflow/assets/wgs_db"

# read in final report; create sample list
cat $final_report | grep "PASS" | awk '{print $1}' > $output_dir/passed_samples.txt
IFS=$'\n' read -d '' -r -a sample_list < $output_dir/passed_samples.txt

# create cache of local
today=`date +%Y%m%d`
cached_db=$wgs_dir/${today}_wgs_db.csv
cp $wgs_dir/wgs_db_master.csv $cached_db

# add a new line
echo "" >> $cached_db

# for each sample, check ID file
for sample_id in ${sample_list[@]}; do
    echo "sample: $sample_id"

    # check if sample already has an ID
    check=`cat $cached_db | grep "$sample_id"`
    
    # if the check passes, add new ID
    if [[ $check == "" ]]; then
        echo "--assigning new ID"
        # determine final ID assigned
        # WGSID,CGR_ID,projectID,DATE_ASSIGNED
        # YYYY-GZ-0001
        last_saved_id=`tail -n1 $cached_db | awk -F"," '{print $1}' | cut -f3 -d"-"`
        stripped_id=`echo "${last_saved_id#"${last_saved_id%%[!0]*}"}"`
        new_id=$(( stripped_id + 1 ))

        # add zeros so the final ID is always four digits
        if [[ $new_id -lt 10 ]]; then
            final_id="000$new_id"
        elif [[ $new_id -lt 100 ]]; then
            final_id="00$new_id"
        elif [[ $new_id -lt 1000 ]]; then
            final_id="0$new_id"
        else
            final_id="$new_id"
        fi

        # add sample with new ID to list
        add_line="2023-GZ-$final_id,$sample_id,$project_id,$today"
        echo $add_line >> $cached_db
    else
        echo "--sample was already assigned an ID"
        echo "----$check"
    fi
done

# create new copy
sed -i '/^$/d' $cached_db
cp $wgs_dir/wgs_db_master.csv $wgs_dir/wgs_db_backup.csv
cp $cached_db $wgs_dir/wgs_db_master.csv
mv $cached_db $wgs_dir/cached