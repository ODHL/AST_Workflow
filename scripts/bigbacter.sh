#https://github.com/DOH-JDJ0303/bigbacter-nf/wiki/2.-Running-BigBacter
flag=$1

if [[ $flag == "db" ]]; then
    cd /home/ubuntu/tools/bigbacter-nf
    /home/ubuntu/tools/nextflow run /home/ubuntu/tools/bigbacter-nf/main.nf \
    -resume \
    -profile docker \
    -entry PREPARE_DB \
    --input /home/ubuntu/workflows/AR_Workflow/config/pp_db_list.csv \
    --db /home/ubuntu/output/bigbacter/db
fi

if [[ $flag == "run" ]]; then
    cd /home/ubuntu/tools/bigbacter-nf
    /home/ubuntu/tools/nextflow run /home/ubuntu/tools/bigbacter-nf/main.nf \
    -resume \
    -profile docker \
    --input /home/ubuntu/output/bigbacter/samplesheet.csv \
    --outdir /home/ubuntu/output/bigbacter/results \
    --db /home/ubuntu/output/bigbacter/db
fi