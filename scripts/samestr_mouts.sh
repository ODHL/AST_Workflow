# set db
db_dir="/home/ubuntu/workflows/refs/mouts"

# move into the db
cd $db_dir

# download
wget https://zenodo.org/records/7778108/files/db_mOTU_v3.1.0.tar.gz

# untar
tar -xzvf db_mOTU_v3.1.0.tar.gz
