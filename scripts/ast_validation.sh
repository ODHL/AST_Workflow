#########################################################
# ARGS
#########################################################
pipeline_test="/home/ubuntu/workflows/phoenix_rewrite/phoenix"
project_id="validation-project"

#########################################################
# Pipeline controls
########################################################
flag_analysis="Y"

#########################################################
# Set dirs, files, args
#########################################################
pipeline_core="/home/ubuntu/workflows/AR_Workflow/"
output_dir="/home/ubuntu/output/$project_id"

##########################################################
# Eval, source
#########################################################
if [[ $flag_analysis == "Y" ]]; then
	
	# init
    if [[ ! -d $output_dir ]]; then
		echo "--init"
	    cd $pipeline_core
		bash $pipeline_core/run_workflow.sh -n $project_id -p init
		cp $pipeline_core/test/sample_ids.txt $pipeline_core/config/sample_ids.txt
	fi
    	
	# pull SRR samples
    if [[ ! -d $output_dir/tmp/rawdata/srr ]]; then
		echo "--SRR"
		cd $pipeline_core
		bash $pipeline_core/scripts/downloadSRR.sh $output_dir
	fi
    
	# batch samples
    if [[ ! -d $output_dir/tmp/rawdata/srr ]]; then
	    echo "--batch"
		cd $pipeline_core
		bash $pipeline_core/run_workflow.sh -n $project_id -p analysis -s BATCH
	fi

	# corrupt sample
	R1="/home/ubuntu/output/validation-project/tmp/rawdata/fastq/SRR5168512c.R1.fastq.gz"
	if [[ ! -f $R1 ]]; then
		echo "--corrupting"
		head -n -1 /home/ubuntu/output/validation-project/tmp/rawdata/fastq/SRR5168512.R1.fastq.gz > temp.txt 
		mv temp.txt $R1

		R2="/home/ubuntu/output/validation-project/tmp/rawdata/fastq/SRR5168512c.R2.fastq.gz"
		cp /home/ubuntu/output/validation-project/tmp/rawdata/fastq/SRR5168512.R2.fastq.gz $R2		
		
		echo "SRR21590951c,$R1,$R2" >> $output_dir/logs/manifests/samplesheet_01.csv
	fi

	# run analysis
	# rm -rf /home/ubuntu/workflows/AR_Workflow/scripts/work
	cmd="/home/ubuntu/tools/nextflow run $pipeline_test/main.nf -resume \
		-profile docker -entry PHOENIX --max_memory 7.GB --max_cpus 4 \
		--input $output_dir/logs/manifests/samplesheet_01.csv \
		--kraken2db /home/ubuntu/refs/kraken2db/ \
		--outdir $output_dir/tmp/pipeline/batch_01 --projectID $project_id"
	echo $cmd
	$cmd
fi