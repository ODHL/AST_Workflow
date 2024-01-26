merged_pipeline=test.txt
	
# read in final report; create sample list
if [[ -f tmp_sampleids.txt ]]; then rm tmp_sampleids.txt; fi
cat test.txt | awk -F"\t" '{print $1}' | grep -v "ID"> tmp_sampleids.txt
IFS=$'\n' read -d '' -r -a sample_list < tmp_sampleids.txt

cp test.txt save

# read in all samples
for id in "${sample_list[@]}"; do
	
	# prep tmp file
	cp test.txt tmp_pipeline

	# pull the sample ID
	specimen_id=$id
	echo $specimen_id
	SID=$(awk -v sid=$specimen_id '{ if ($1 == sid) print NR }' test.txt)

	# pull the needed variables
	Auto_QC_Outcome=`cat test.txt | awk -F"\t" -v i=$SID 'FNR == i {print $2}'`
	Estimated_Coverage=`cat test.txt | awk -F"\t" -v i=$SID 'FNR == i {print $3}'`
        
	# check if the failure is real
	cov_replace="autofail($Estimated_Coverage)"
	if [[ $Estimated_Coverage -gt 29 ]]; then
		awk -F"\t" -v i=$SID 'NR==i {$2="PASS"}1' test.txt > tmp_pipeline
	else
		cov_replace="autofail($Estimated_Coverage)"
		awk -F"\t" -v i=$SID -v cov=$cov_replace 'NR==i {$4=cov}1' test.txt > tmp_pipeline
	fi

	sed -i "s/autofail(0)//g" tmp_pipeline
	cp tmp_pipeline test.txt
done
cat test.txt
echo
cp save test.txt