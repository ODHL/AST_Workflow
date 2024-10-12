#########################################################
# ARGS
#########################################################
pipeline_results=$1

# stats
num_samples=`cat $pipeline_results | grep -v "ID" | wc -l`
num_discordance=`cat $pipeline_results | grep "Discordance" | wc -l`
num_concordant=`cat $pipeline_results | grep "PASS" | wc -l`
num_failed=`cat $pipeline_results | grep -v "Discordance" | awk -F";" '{print $2}' | grep "FAIL" | wc -l`

echo "TOTAL: $num_samples | PASSED: $num_concordant | FAILED: $num_discordance discordant, $num_failed other failures"