#!/bin/sh
if [ $# -ne 8 ] && [ $# -ne 11 ]; then
  echo "please use: $0 factor result_dir ip port dbname user pwd { row|column|pg }"
  echo "or"
  echo "$0 factor result_dir ip port dbname user pwd redshift s3_prefix ec2_id ec2_key"
  exit 1
fi

SF=$1
#first clear runtime directory
RUNTIME_DIR="./runtime"
TEMPLATES_DIR="./templates"
rm -rf $RUNTIME_DIR
mkdir -p $RUNTIME_DIR

#init query loadata
./generate_load_data.sh $SF

#copy template to runtime
cp -r  $TEMPLATES_DIR/general $RUNTIME_DIR/general

original_dir=`pwd`
#generate query and update sql
cd $RUNTIME_DIR/general
./generate_sql.sh $SF

#start test
if [ $# -eq 11 ]; then
  ./tpch.sh $2 $3 $4 $5 $6 $7 $8 $9 $10 $11
else
  ./tpch.sh $2 $3 $4 $5 $6 $7 $8
fi

cd $original_dir

