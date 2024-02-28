#########################################################
# functions
#########################################################
parse_yaml() {
   local prefix=$2
   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|^\($s\)\($w\)$s:$s\"\(.*\)\"$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
   awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
      }
   }'
}

message_cmd_log(){
        msg="$1"
        echo $msg >> $pipeline_log
	echo $msg
}

message_stats_log(){
	msg="$1"
	echo "$msg" >> $stats_log
	echo "$msg"

}

handle_fq(){
	in_fq=$1
	in_fqID=$2
	in_treedir=$3

	if [[ ! -f $in_fq/$in_fqID ]]; then
		if [[ -f $in_treedir/$in_fqID ]]; then 
			mv $in_treedir/$in_fqID $in_fq/$in_fqID
		else 
			echo "missing $in_treedir/$in_fqID"
			exit
		fi
	fi	

}

clean_file_insides(){
	sed -i "s/[_-]ASTVAL//g" $1
	sed -i "s/[_-]AST//g" $1
	sed -i "s/-$project_name_full//g" $1
	sed -i "s/-$project_name//g" $1		
	sed -i "s/-OH//g" $1
   	sed -i "s/_001//g" $1
   	sed -i "s/_S[0-9]*_//g" $1
   	sed -i "s/_L001//g" $1
}

clean_file_names(){
	out=`echo $1 | sed "s/[_-]ASTVAL//g" | sed "s/[_-]AST//g" | sed "s/-$project_name_full//g" | sed "s/-$project_name//g"`
	out=`echo $out | sed "s/-OH//g" | sed "s/_S[0-9]*//g" | sed "s/_L001//g" | sed "s/_001//g" | sed "s/_R/.R/g"`
   echo $out
}

makeDirs(){
	new=$1
	if [[ ! -d $$new ]]; then mkdir -p $new; fi
}

runMULTIQC(){
	qc_report=$report_dir/multiqc_report.html
	if [[ ! -f $qc_report ]]; then
        multiqc -f -v \
        -c $multiqc_config \
        $fastqc_dir \
        -o $qcreport_dir 2>&1 | tee -a $multiqc_log

        mv $qcreport_dir/multiqc_report.html $qc_report
    fi
}

prepREPORT(){
	micropath=$1
    intermedpath="$micropath/analysis/intermed"
    reportpath="$micropath/analysis/reports"
    arCONFIG="$micropath/logs/config/config_ar_report.yaml"
	metapath="$micropath/metadata.csv"
	todaysdate=$(date '+%Y-%m-%d')
    sed -i "s~REP_CONFIG~$arCONFIG~g" $arRMD
    sed -i "s/REP_PROJID/$project_name/g" $arRMD
    sed -i "s~REP_OUT~$micropath/reports/~g" $arRMD
    sed -i "s~REP_DATE~$todaysdate~g" $arRMD
    sed -i "s~REP_ST~$reportpath/final_report.csv~g" $arRMD
    sed -i "s~REP_SNP~$intermedpath/snp_distance_matrix.tsv~g" $arRMD
    sed -i "s~REP_TREE~$intermedpath/core_genome.tree~g" $arRMD
    sed -i "s~REP_CORE~$intermedpath/core_genome_statistics.txt~g" $arRMD
    sed -i "s~REP_AR~$intermedpath/ar_predictions.tsv~g" $arRMD
    sed -i "s~REP_LOGO~$config_logo_file~g" $arRMD
    sed -i "s~REP_META~$metapath~g" $arRMD
}