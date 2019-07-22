#!/bin/sh
if [ $# -ne 9 ] && [ $# -ne 12 ]; then
  echo "please use: $0 factor stream_count result_dir ip port dbname user pwd { row|column|pg }"
  echo "or"
  echo "$0 factor stream_count result_dir ip port dbname user pwd redshift s3_prefix ec2_id ec2_key"
  exit 1
fi


SF=1
STREAM_COUNT

RUNTIME_DIR="./runtime"
TEMPLATES_DIR="./templates"

original_dir=`pwd`

#copy query template to runtime
for i in $seq(1, $STREAM_COUNT) {
  #copy template to runtime
  cp -r  $TEMPLATES_DIR/throughput_query $RUNTIME_DIR/throughput_query_$i
  cd $RUNTIME_DIR/throughput_query_$i
  ./generate_sql.sh $SF
  cd $original_dir
}

#copy update template to runtime
cp -r  $TEMPLATES_DIR/throughput_update $RUNTIME_DIR/throughput_update
cd $RUNTIME_DIR/throughput_update
./generate_update.sh $SF $STREAM_COUNT
cd $original_dir

#async run query
for i in $seq(1, $STREAM_COUNT) {
  cd $RUNTIME_DIR/throughput_query_$i
  if [ $# -eq 12 ]; then
    ./run_query.sh $3 $4 $5 $6 $7 $8 $9 $10 $11 $12 &
  else
    ./run_query.sh $3 $4 $5 $6 $7 $8 $9 &
  fi
  cd $original_dir
}

#async run update
cd $RUNTIME_DIR/throughput_update
if [ $# -eq 12 ]; then
    ./run_update.sh $3 $4 $5 $6 $7 $8 $9 $10 $11 $12 &
  else
    ./run_update.sh $3 $4 $5 $6 $7 $8 $9 &
  fi

cd $original_dir