#########################################################
# ARGS
#########################################################
output_dir=$1
project_id=$2
pipeline_config=$3
wgs_results=$4
ncbi_results=$5
subworkflow=$6
pipeline_results=$7
pipeline_log=$8

#########################################################
# Eval, source
#########################################################
source $(dirname "$0")/core_functions.sh
eval $(parse_yaml ${pipeline_config} "config_")

#########################################################
# Set dirs, files, args
#########################################################
# set date
date_stamp=`date '+%Y_%m_%d'`

# set dirs
log_dir=$output_dir/logs
ncbi_dir=$output_dir/tmp/ncbi
fastq_dir=$output_dir/tmp/rawdata/fastq

# set files
metadataFILE=${config_metadata_file}

# set basespace command
basespace_command=${config_basespace_cmd}

# backup
cp srr_db/srr_db_master.csv srr_db/srr_db_backup.csv
#########################################################
# Controls
#########################################################
# to run cleanup of frameshift samples, pass frameshift_flag
flag_batch="N"
flag_manifests="N"
flag_fastqs="N"
flag_check="N"
flag_post="N"
if [[ $subworkflow == "BATCH" ]]; then
	flag_batch="Y"
elif [[ $subworkflow == "PREP" ]]; then
	flag_manifests="Y"
elif [[ $subworkflow == "FASTQ" ]]; then
	flag_fastqs="Y"
elif [[ $subworkflow == "PRECHECK" ]]; then
	flag_precheck="Y"
elif [[ $subworkflow == "UPLOAD" ]]; then
	flag_batch="Y"
	flag_manifests="Y"
	flag_fastqs="Y"
	flag_precheck="Y"
elif [[ $subworkflow == "POST" ]]; then
	flag_post="Y"
fi

# check the metadata file is available before processing
if [[ ! -f $metadataFILE ]]; then echo "METADATA FILE IS MISSING: $metadataFILE"; exit; fi

#########################################################
# Code
#########################################################
if [[ $flag_batch == "Y" ]]; then
	message_cmd_log "------------------------------------------------------------------------"
	message_cmd_log "--- BATCHING ---"
	message_cmd_log "------------------------------------------------------------------------"
		
	# pull samples that have passed QC, have WGS-IDs
	passed_samples="$ncbi_dir/passed_list.txt"
	if [[ -f $passed_samples ]]; then rm $passed_samples; rm passed_samples; fi
	touch $passed_samples

	cat $pipeline_results | grep "PASS" | awk -F";" '{print $1}' | uniq > passed_samples
	IFS=$'\n' read -d '' -r -a sample_list < passed_samples
	for id in "${sample_list[@]}"; do
		if [[ $id == *"SRR"* ]]; then
			echo "SRR sample: $id"
		else
			wgs_id=`cat wgs_db/wgs_db_master.csv | grep $id | cut -f1 -d","`
			srr_old=`cat srr_db/srr_db_master.csv | grep $wgs_id | cut -f1 -d","` 
			if [[ $srr_old == "" ]]; then
				echo "NEW SAMPLE: $id ($wgs_id)"
				echo $id >> $passed_samples
			else
				echo "SRR already exists: $srr_old ($id)"
			fi
		fi
	done

	# split into chunks of 50
	split $passed_samples $ncbi_dir/manifest_batch_ --numeric=1 -l 50 --numeric-suffixes --additional-suffix=.txt

	# determine batches and make dirs
	batch_count=`ls $ncbi_dir/manifest_batch_* | wc -l`
	batch_min=1
	rm -rf $ncbi_dir/batch*
	for (( batch_id=$batch_min; batch_id<=$batch_count; batch_id++ )); do
		batch_dir="$ncbi_dir/batch_0${batch_id}"
		mkdir $batch_dir
		mv $ncbi_dir/manifest_batch_0${batch_id}.txt $batch_dir
	done
fi

if [[ $flag_manifests == "Y" ]]; then
	message_cmd_log "------------------------------------------------------------------------"
	message_cmd_log "--- MANIFESTS ---"
	message_cmd_log "------------------------------------------------------------------------"
	batch_count=`ls $ncbi_dir/*/manifest_batch_* | wc -l`
	batch_min=1
	
	for (( batch_id=$batch_min; batch_id<=$batch_count; batch_id++ )); do
		batch_dir="$ncbi_dir/batch_0$batch_id"
		batch_manifest="$batch_dir/manifest_batch_0${batch_id}.txt"
		ncbi_attributes=$batch_dir/batched_ncbi_att_${project_id}_${date_stamp}.tsv
		ncbi_metadata=$batch_dir/batched_ncbi_meta_${project_id}_${date_stamp}.tsv

		# Create manifest for attribute upload
		chunk1="*sample_name\tsample_title\tbioproject_accession\t*organism\tstrain\tisolate\thost"
		chunk2="isolation_source\t*collection_date\t*geo_loc_name\t*sample_type\taltitude\tbiomaterial_provider\tcollected_by\tculture_collection\tdepth\tenv_broad_scale"
		chunk3="genotype\thost_tissue_sampled\tidentified_by\tlab_host\tlat_lon\tmating_type\tpassage_history\tsamp_size\tserotype"
		chunk4="serovar\tspecimen_voucher\ttemp\tdescription\tMLST"
		echo -e "${chunk1}\t${chunk2}\t${chunk3}\t${chunk4}" > $ncbi_attributes

		# Create manifest for metadata upload
		chunk1="sample_name\tlibrary_ID\ttitle\tlibrary_strategy\tlibrary_source\tlibrary_selection"
		chunk2="library_layout\tplatform\tinstrument_model\tdesign_description\tfiletype\tfilename"
		chunk3="filename2\tfilename3\tfilename4\tassembly\tfasta_file"
		echo -e "${chunk1}\t${chunk2}\t${chunk3}" > $ncbi_metadata

		# process samples
		IFS=$'\n' read -d '' -r -a sample_list < $batch_manifest
		for id in "${sample_list[@]}"; do
			# set variables from wgs_results
			wgsID=`cat $wgs_results | grep $id | awk -F"," '{print $2}'`
			SID=$(awk -F";" -v sid=$id '{ if ($1 == sid) print NR }' $pipeline_results)
			organism=`cat $pipeline_results | awk -F";" -v i=$SID 'FNR == i {print $14}' | sed "s/([0-9]*.[0-9]*%)//g" | sed "s/  //g"`
			
			# grab metadata line
			meta=`cat $metadataFILE | grep "$id"`

			# check if it's been uploaded; if it has ignore
			sraID=`cat srr_db/srr_db_master.csv | grep $SID | awk -F"," '{print $1}'`

			#if meta is found create input metadata row
			if [[ ! "$meta" == "" ]] && [[ ! "$sraID" == "" ]]; then
				#convert date to ncbi required format - 4/21/81 to 1981-04-21
				raw_date=`echo $meta | grep -o "[0-9]*/[0-9]*/202[0-9]*"`
				collection_yr=`echo "${raw_date}" | awk '{split($0,a,"/"); print a[3]}' | tr -d '"'`

				# set title
				sample_title=`echo "Illumina Sequencing of ${wgsID}"`
				
				# pull source
				#isolation_source=`echo $meta | grep -o --e "Fluid (Body)_Sputum (bronchial scope)" -e "BA" -e "Septum" -e "Tissue" -e "Wound" -e "Tracheal Aspirate" -e "Urine" -e "Blood" -e "Other" -e "RESP Endotrach" -e "Tissue_Other`
				isolation_source=`echo $meta | awk -F"," '{print $11}'`

				# pull instrument
				instrument_model=`echo $project_id | cut -f2 -d"-"| grep -o "^."`
				if [[ $instrument_model == "M" ]]; then instrument_model="Illumina MiSeq"; else instrument_model="NextSeq 1000"; fi

				# get MLST
				MLST=`cat $pipeline_results | grep $id | awk -F";" '{print $25}'`

				# break output into chunks
				chunk1="${wgsID}\t${sample_title}\t${config_bioproject_accession}\t${organism}\t${config_strain}\t${wgsID}\t${config_host}"
				chunk2="${isolation_source}\t${collection_yr}\t${config_geo_loc_name}\t${config_sample_type}\t${config_taltitude}"
				chunk3="${config_biomaterial_provider}\t${config_tcollected_by}\t${config_culture_collection}\t${config_depth}"
				chunk4="${config_env_broad_scale}\t${config_genotype}\t${config_host_tissue_sampled}\t${config_identified_by}"
				chunk5="${config_lab_host}\t${config_lat_lon}\t${config_mating_type}\t${config_passage_history}\t${config_samp_size}"
				chunk6="${config_serotype}\t${config_serovar}\t${config_specimen_voucher}\t${config_temp}\t${config_description}\t${MLST}"
				
				# add output variables to attributes file
				echo -e "${chunk1}\t${chunk2}\t${chunk3}\t${chunk4}\t${chunk5}\t${chunk6}\t${chunk7}\t${chunk8}\t${chunk9}\t${chunk10}\t${chunk11}\t${chunk12}" >> $ncbi_attributes
			
				# breakoutput into chunks
				chunk1="${wgsID}\t${wgsID}\t${sample_title}\t${config_library_strategy}\t${config_library_source}\t${config_library_selection}"
				chunk2="${config_library_layout}\t${config_platform}\t${instrument_model}\t${config_design_description}\t${config_filetype}\t${id}.R1.fastq.gz"
				chunk3="${id}.R2.fastq.gz\t${config_filename3}\t${config_filename4}\t${assembly}\t${config_fasta_file}"

				# add output variables to attributes file
				echo -e "${chunk1}\t${chunk2}\t${chunk3}" >> $ncbi_metadata

				# check
				echo "Found metadata $id"
	    	else
	    		echo "Missing metadata $id"
	    	fi
    	done
	done
fi

if [[ $flag_fastqs == "Y" ]]; then
	message_cmd_log "------------------------------------------------------------------------"
	message_cmd_log "--- PREPARE FQ ---"
	message_cmd_log "------------------------------------------------------------------------"
	batch_count=`ls $ncbi_dir/*/manifest_batch_* | wc -l`
	batch_min=1
	
	for (( batch_id=$batch_min; batch_id<=$batch_count; batch_id++ )); do
		batch_dir="$ncbi_dir/batch_0$batch_id"
		batch_manifest="$batch_dir/manifest_batch_0${batch_id}.txt"

		# process samples
		IFS=$'\n' read -d '' -r -a sample_list < $batch_manifest
		for id in "${sample_list[@]}"; do
			R1="$fastq_dir/$id*R1*"
			R2="$fastq_dir/$id*R2*"

			# check R1
			if [[ ! -f "$batch_dir/$id*R1*" ]]; then cp $R1 $batch_dir; else echo "MISSING FASTQ FILE: $R1"; fi

			# check R2
			if [[ ! -f "$batch_dir/$id*R2*" ]]; then cp $R2 $batch_dir; else echo "MISSING FASTQ FILE: $R2"; fi
		done
	done
fi

if [[ "$flag_precheck" == "Y" ]]; then
	message_cmd_log "------------------------------------------------------------------------"
	message_cmd_log "--- UPLOAD CHECK ---"
	message_cmd_log "------------------------------------------------------------------------"
	batch_count=`ls $ncbi_dir/*/manifest_batch_* | wc -l`
	batch_min=1
	
	for (( batch_id=$batch_min; batch_id<=$batch_count; batch_id++ )); do
		batch_dir="$ncbi_dir/batch_0$batch_id"
		batch_manifest="$batch_dir/manifest_batch_0${batch_id}.txt"
		ncbi_attributes=$batch_dir/batched_ncbi_att_${project_id}_${date_stamp}.tsv
		ncbi_metadata=$batch_dir/batched_ncbi_meta_${project_id}_${date_stamp}.tsv

		# process samples
		IFS=$'\n' read -d '' -r -a sample_list < $batch_manifest
		for id in "${sample_list[@]}"; do
			# check FASTQ is in dir
			R1=`ls $batch_dir | grep $id | grep R1`
			R2=`ls $batch_dir | grep $id | grep R2`
			if [[ $R1 == "" ]] || [[ $R2 == "" ]]; then echo "----$id R1/R2 Error"; fi
			
			# check ID is in attributes and metadata
			wgsID=`cat $wgs_results | grep $id | awk -F"," '{print $2}'`
			att=`cat $ncbi_attributes | grep $wgsID`
			meta=`cat $ncbi_metadata | grep $wgsID`
			if [[ $att == "" ]] || [[ $meta == "" ]]; then echo "----$id ATT/META Error"; fi
		done
	done
	echo "-----READY FOR UPLOAD"
	echo "$batch_dir"
fi

if [[ "$flag_post" == "Y" ]]; then
	message_cmd_log "------------------------------------------------------------------------"
	message_cmd_log "--- POST ---"
	message_cmd_log "------------------------------------------------------------------------"
	
	# prep results file
	if [[ -f $ncbi_results ]]; then rm $ncbi_results; fi
	echo "WGSID,SRRID,SAMID" > $ncbi_results

	batch_count=`ls $ncbi_dir/*/manifest_batch_* | wc -l`
	batch_min=1
	cp srr_db/srr_db_master.csv srr_db/srr_db_backup.csv
	cp srr_db/srr_db_backup.csv srr_db/srr_db_tmp.csv
	
	for (( batch_id=$batch_min; batch_id<=$batch_count; batch_id++ )); do
		batch_dir="$ncbi_dir/batch_0$batch_id"
		batch_manifest="$batch_dir/manifest_batch_0${batch_id}.txt"
		ncbi_output=$batch_dir/*ok*

		# cp manifests 
		cp $batch_manifest $log_dir/manifests/ncbi_batch_0$batch_id.tsv
		cp $ncbi_output $output_dir/analysis/intermed/ncbi_output_0$batch_id.tsv
		
		# process samples
		IFS=$'\n' read -d '' -r -a sample_list < $batch_manifest
		for id in "${sample_list[@]}"; do
			# create list of samples uploaded to ncbi
			wgsID=`cat $wgs_results | grep $id | awk -F"," '{print $2}'`
			sraID=`cat $ncbi_output | grep $wgsID | awk '{print $1}'`
			samID=`cat $ncbi_output | grep $wgsID | awk '{print $5}'`
			if [[ $sraID == "" ]]; then 
				sraID="NO_ID"
				samID="NO_ID"
			else
				# add to final output
				echo "$sraID,$wgsID,$samID,$project_id" >> srr_db/srr_db_tmp.csv
			fi			
			
			echo "$wgsID,$sraID,$samID" >> $ncbi_results
		done
	done

	cat $ncbi_results
	mv srr_db/srr_db_tmp.csv srr_db/srr_db_master.csv
fi