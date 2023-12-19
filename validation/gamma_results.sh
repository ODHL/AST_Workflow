# gather gamma-ar results
proj="OH-M6588-230725-AST"
gamma_results="/home/ubuntu/output/$proj/pipeline/gamma_results_231020_2.csv"

if [ -f $gamma_results ]; then rm $gamma_results; fi

for f in /home/ubuntu/output/$proj/pipeline/batch_1/*/gamma_ar/*.gamma; do
    id=`echo $f | cut -f8 -d"/"`
    awk '{printf "%s%s",sep,$1; sep=","} END{print ""}' $f | sed "s/Gene/$id/g" >> $gamma_results
	cp $f /home/ubuntu/output/$proj/pipeline/ 
done

sed -i "s/-//g" $gamma_results

for f in /home/ubuntu/output/$proj/pipeline/batch_1/*/kraken*/*wtasmbld_summary*; do
	cp $f /home/ubuntu/output/$proj/pipeline/
done
