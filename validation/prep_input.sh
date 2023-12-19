gamma_dir="/home/ubuntu/output/species"
species_out="$gamma_dir/species_list.txt"

rm $species_out

for f in $gamma_dir/*; do 
	g=`cat $f | grep "G:" | cut -f3 -d" "`
	s=`cat $f | grep "s:" | cut -f3 -d" "`
	n=`echo $f | cut -f6 -d"/" | cut -f1 -d"."`
	echo "$n,$g $s" >> $species_out
done

gamma_dir="/home/ubuntu/output/gamma"
gamma_out="$gamma_dir/gene_list_clean.txt"

rm $gamma_out

for f in $gamma_dir/*; do
    id=`echo $f | cut -f6 -d"/" | sed "s/_ResGANNCBI_20230517_srst2.gamma//g"`
	line=`awk '{print $1}' $f | sort | uniq | awk '{printf "%s%s",sep,$1; sep=","} END{print ""}' | sed "s/,Gene//g"`
	echo "$id,$line" >> $gamma_out
done

cat $gamma_out