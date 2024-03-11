# set db
db_dir="/home/ubuntu/workflows/refs"

# move into the db
cd $db_dir

# download
wget -P db_MetaPhlAn/ http://cmprod1.cibio.unitn.it/biobakery4/metaphlan_databases/mpa_vJun23_CHOCOPhlAnSGB_202307.tar

# untar
tar -xvf db_MetaPhlAn/mpa_vJun23_CHOCOPhlAnSGB_202307.tar

# concatenate
cat db_MetaPhlAn/mpa_vJun23_CHOCOPhlAnSGB_202307_SGB.fna.bz2 \
    db_MetaPhlAn/mpa_vJun23_CHOCOPhlAnSGB_202307_VSG.fna.bz2 > \
        db_MetaPhlAn/mpa_vJun23_CHOCOPhlAnSGB_202307.fna.bz2
