sample_manifest="sample_manifest.csv"
#output_dir="/home/ubuntu/output/OH-M6588-230629-AST"
output_dir="/home/ubuntu/output/ncbi"
IFS=$'\n' read -d'' -r -a sample_data < $sample_manifest

cd $output_dir
for sdata in "${sample_data[@]}"; do
    SRRNUM=`echo $sdata | cut -f3 -d","`
    BANKID=`echo $sdata | cut -f4 -d","`
    echo "--$SRRNUM | $BANKID"
    if [[ ! -f $output_dir/tmp/${BANKID}_ds/${BANKID}_S7_L001_R1_001.fastq.gz ]]; then
        echo "----fetching"
        prefetch $SRRNUM
        
        echo "----FASTQ"
        cd $SRRNUM
        fastq-dump --outdir fastq --gzip --skip-technical  --readids --read-filter pass --dumpbase --split-3 --clip  $SRRNUM.sra
        cd fastq

        echo "----cleaning"
        if [[ ! -d $output_dir/tmp/${BANKID}_ds ]]; then mkdir -p $output_dir/tmp/${BANKID}_ds; fi
        mv ${SRRNUM}_pass_1.fastq.gz $output_dir/tmp/${BANKID}_ds/${BANKID}_S7_L001_R1_001.fastq.gz
        mv ${SRRNUM}_pass_2.fastq.gz $output_dir/tmp/${BANKID}_ds/${BANKID}_S7_L001_R2_001.fastq.gz
        cd ../..
        sudo rm -r $SRRNUM  
    fi
done