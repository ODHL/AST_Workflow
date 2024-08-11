output_dir="$1"
IFS=$'\n' read -d '' -r -a raw_list < config/sample_ids.txt

raw_dir=$output_dir/tmp/rawdata
srr_dir=$raw_dir/srr
if [[ ! -d $srr_dir ]]; then mkdir -p $srr_dir; fi

cd $output_dir
for SRRLINE in "${raw_list[@]}"; do
	SRRNUM=`echo $SRRLINE | cut -f1 -d";"`
    if [[ $SRRNUM =~ "SRR" ]]; then
        echo "--$SRRNUM"
        if [[ ! -f "$raw_dir/${SRRNUM}*.gz" ]]; then
            echo "----fetching"
            prefetch $SRRNUM
            
            echo "----FASTQ"
            cd $SRRNUM
            fastq-dump --outdir fastq --gzip --skip-technical  --readids --read-filter pass --dumpbase --split-3 --clip  $SRRNUM.sra
            cd fastq

            echo "----cleaning"
            mv ${SRRNUM}_pass_1.fastq.gz $raw_dir/fastq/${SRRNUM}.R1.fastq.gz
            mv ${SRRNUM}_pass_2.fastq.gz $raw_dir/fastq/${SRRNUM}.R2.fastq.gz
        fi
    fi
done