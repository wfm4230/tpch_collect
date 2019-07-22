#!/bin/sh

if [ $# -ne 7 ] && [ $# -ne 10 ]; then
  echo "please use: $0 result_dir ip port dbname user pwd { row|column|pg }"
  echo "or"
  echo "$0 result_dir ip port dbname user pwd redshift s3_prefix ec2_id ec2_key"
  exit 1
fi

RESULTS=$1
IP=$2
PORT=$3
DBNAME=$4
USER=$5
PASSWORD=$6
STORAGE=$7

if [ $STORAGE != 'row' ] && [ $STORAGE != 'column' ] && [ $STORAGE != 'redshift' ] && [ $STORAGE != 'pg' ] && [ $STORAGE != 'pg10' ] && [ $STORAGE != 'citus' ]; then
  echo "you must enter { row | column | redshift | pg | pg10 | citus }"
  exit 1
fi

if [ $STORAGE == 'redshift' ]; then
S3=$8
EC2_ID=$9
EC2_KEY=$10
fi

DEP_CMD="psql"
which $DEP_CMD 
if [ $? -ne 0 ]; then
  echo -e "dep commands: $DEP_CMD not exist."
  exit 1
fi

export PGPASSWORD=$PASSWORD

# delay between stats collections (iostat, vmstat, ...)
DELAY=15

# DSS queries timeout
DSS_TIMEOUT=300000     # seconds

# log
LOGFILE=bench.log

function benchmark_run() {

	mkdir -p $RESULTS

	print_log "store the settings"
	psql -h $IP -p $PORT -U $USER $DBNAME -c "select name,setting from pg_settings" > $RESULTS/settings.log 2> $RESULTS/settings.err

	print_log "running TPC-H benchmark"

	benchmark_dss $RESULTS

	print_log "finished TPC-H benchmark"

}

function benchmark_dss() {

	mkdir -p $RESULTS

	mkdir $RESULTS/vmstat-s $RESULTS/vmstat-d $RESULTS/explain $RESULTS/results $RESULTS/errors

	# get bgwriter stats
	psql -h $IP -p $PORT -U $USER $DBNAME -c "SELECT * FROM pg_stat_bgwriter" > $RESULTS/stats-before.log 2>> $RESULTS/stats-before.err
	psql -h $IP -p $PORT -U $USER $DBNAME -c "SELECT * FROM pg_stat_database WHERE datname = '$DBNAME'" >> $RESULTS/stats-before.log 2>> $RESULTS/stats-before.err

	vmstat -s > $RESULTS/vmstat-s-before.log 2>&1
	vmstat -d > $RESULTS/vmstat-d-before.log 2>&1

	print_log "running queries defined in TPC-H benchmark"

	for n in `seq 1 22`
	do

		q="dss/queries/$n.sql"

		if [ -f "$q" ]; then

			print_log "  running query $n"

			echo "======= query $n =======" >> $RESULTS/data.log 2>&1;


			vmstat -s > $RESULTS/vmstat-s/before-$n.log 2>&1
			vmstat -d > $RESULTS/vmstat-d/before-$n.log 2>&1

			print_log "run the query on background"
			/usr/bin/time -a -f "$n = %e" -o $RESULTS/results.log psql -h $IP -p $PORT -U $USER $DBNAME < $q > $RESULTS/results/$n 2> $RESULTS/errors/$n

			vmstat -s > $RESULTS/vmstat-s/after-$n.log 2>&1
			vmstat -d > $RESULTS/vmstat-d/after-$n.log 2>&1

		fi;

	done;

	# collect stats again
	psql -h $IP -p $PORT -U $USER $DBNAME -c "SELECT * FROM pg_stat_bgwriter" > $RESULTS/stats-after.log 2>> $RESULTS/stats-after.err
	psql -h $IP -p $PORT -U $USER $DBNAME -c "SELECT * FROM pg_stat_database WHERE datname = '$DBNAME'" >> $RESULTS/stats-after.log 2>> $RESULTS/stats-after.err

	vmstat -s > $RESULTS/vmstat-s-after.log 2>&1
	vmstat -d > $RESULTS/vmstat-d-after.log 2>&1

}

function stat_collection_start()
{

	local RESULTS=$1

	# run some basic monitoring tools (iotop, iostat, vmstat)
	for dev in $DEVICES
	do
		iostat -t -x /dev/$dev $DELAY >> $RESULTS/iostat.$dev.log &
	done;

	vmstat $DELAY >> $RESULTS/vmstat.log &

}

function stat_collection_stop()
{

	# wait to get a complete log from iostat etc. and then kill them
	sleep $DELAY

	for p in `jobs -p`; do
		kill $p;
	done;

}

function print_log() {

	local message=$1

	echo `date +"%Y-%m-%d %H:%M:%S"` "["`date +%s`"] : $message" >> $RESULTS/$LOGFILE;

}

mkdir $RESULTS;

# start statistics collection
stat_collection_start $RESULTS

# run the benchmark
benchmark_run $RESULTS $DBNAME $USER

# stop statistics collection
stat_collection_stop
