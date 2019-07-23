#!/bin/sh
if [ $# -ne 9 ] && [ $# -ne 12 ]; then
  echo "please use: $0 factor stream_count result_dir ip port dbname user pwd { row|column|pg }"
  echo "or"
  echo "$0 factor stream_count result_dir ip port dbname user pwd redshift s3_prefix ec2_id ec2_key"
  exit 1
fi


SF=$1
STREAM_COUNT=$2

RUNTIME_DIR="./runtime"
TEMPLATES_DIR="./templates"

if [ ! -d $RUNTIME_DIR ]; then
  echo "you should run power test first"
  exit 1
fi

original_dir=`pwd`

#copy query template to runtime
for i in $(seq 1 $STREAM_COUNT) 
do
  #copy template to runtime
  cp -r  $TEMPLATES_DIR/throughput_query $RUNTIME_DIR/throughput_query_$i
  cd $RUNTIME_DIR/throughput_query_$i
  ./generate_sql.sh $SF
  cd $original_dir
done

#copy update template to runtime
cp -r  $TEMPLATES_DIR/throughput_update $RUNTIME_DIR/throughput_update
cd $RUNTIME_DIR/throughput_update
./generate_update.sh $SF $STREAM_COUNT
cd $original_dir

#async run query
for i in $(seq 1 $STREAM_COUNT) 
do
  cd $RUNTIME_DIR/throughput_query_$i
  if [ $# -eq 12 ]; then
    ./run_query.sh $3 $4 $5 $6 $7 $8 $9 $10 $11 $12 &
  else
    ./run_query.sh $3 $4 $5 $6 $7 $8 $9 &
  fi
  cd $original_dir
done

query_pid=$!

#async run update
cd $RUNTIME_DIR/throughput_update
if [ $# -eq 12 ]; then
    ./run_update.sh $3 $4 $5 $6 $7 $8 $9 $10 $11 $2 &
  else
    ./run_update.sh $3 $4 $5 $6 $7 $8 $2 &
  fi

update_pid=$! 

# wait up to the given number of seconds, then terminate the query if still running (don't wait for too long)
for i in `seq 0 $DSS_TIMEOUT`
do
  # the query is still running - check the time
  if [ -d "/proc/$query_pid" -o  -d "/proc/$update_pid" ]; then

    # the time is over, kill it with fire!
    if [ $i -eq $DSS_TIMEOUT ]; then

      echo "    waiting (timeout)"

      psql -h $IP -p $PORT -U $USER $DBNAME -c "SELECT pg_terminate_backend(procpid) FROM pg_stat_activity WHERE datname = '$DBNAME'"  2>&1;

      # time to do a cleanup
      sleep 10;

      # just check how many backends are there (should be 0)
      psql -h $IP -p $PORT -U $USER $DBNAME -c "SELECT COUNT(*) AS tpch_backends FROM pg_stat_activity WHERE datname = '$DBNAME'"  2>&1;

    else
      if [ `expr $i %60` -eq 0 ]; then
        echo "after $i seconds still running"
      fi
      # the query is still running and we have time left, sleep another second
      sleep 1;
    fi;

  else
    # the finished in time, do not wait anymore
    echo "thoughoutput test finished"
    break;

  fi;

done;

cd $original_dir