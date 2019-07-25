#!/bin/sh
if [ ! -n "$1" ] ;then
  echo "please use: $0 factor"
  exit 1
fi
SF=$1
SRC_DATA=./test_data/${SF}G
mkdir -p $SRC_DATA
original_dir=`pwd`
cd $SRC_DATA &&  DSS_DIST=../../tpch_tools/218/dists.dss ../../tpch_tools/218/dbgen -s $SF -f
for i in `ls *.tbl`; do 
  csv_name=${i/tbl/csv}
  mv $i $csv_name
  sed -i 's/|$//' $csv_name
  echo $csv_name
done 
rm -rf /tmp/dss-data
ln -s `pwd` /tmp/dss-data
cd $original_dir

