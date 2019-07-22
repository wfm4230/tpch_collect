#!/bin/sh
if [ $# -ne 2 ]; then
  echo "please use: $0 factor stream_count"
  exit 1
fi
SF=$1
STREAM_COUNT=$2
rm -rf dss/updates
mkdir -p dss/updates
SRC_DATA=../../test_data/${SF}G/updates
rm -rf $SRC_DATA
mkdir -p $SRC_DATA

original_dir=`pwd`
cd $SRC_DATA &&  DSS_DIST=../../../tpch_tools/218/dists.dss ../../../tpch_tools/218/dbgen -s $SF -U$STREAM_COUNT && cd $original_dir

for i in `ls $SRC_DATA/*.tbl.*`; do
   file_no=`echo $i|cut -d/ -f 6|cut -d. -f 3`
   table=`echo $i|cut -d/ -f 6|cut -d. -f 1`
   sql_name=rf1_${file_no}.sql
   echo $sql_name
   while read line
   do
    INSERT_SQL="INSERT INTO $table values("
    OLD_IFS="$IFS"
    IFS="|"
    arr=($line)
    arr_len=${#arr[@]}
    j=0
    for data in ${arr[@]}; do
       quoted_data=${data/\'/\'\'}
       INSERT_SQL="${INSERT_SQL} '${quoted_data}'"
       let j++
       if [ "$j" -lt "$arr_len" ]; then
         INSERT_SQL="${INSERT_SQL},";
       fi  
    done
    INSERT_SQL="${INSERT_SQL});";
    echo $INSERT_SQL >> dss/updates/$sql_name
    IFS="$OLD_IFS"
   done < $i
done

for i in `ls $SRC_DATA/delete.*`; do
   file_no=`echo $i|cut -d/ -f 6|cut -d. -f 2`
   table=`echo $i|cut -d/ -f 6|cut -d. -f 1`
   sql_name=rf2_u${file_no}.sql
   echo $sql_name
   while read line
    do
    OLD_IFS="$IFS"
    IFS="|"
    arr=($line)
    del_sql1="DELETE FROM ORDERS WHERE O_ORDER_KEY=${arr[0]}"
    del_sql2="DELETE FROM LINEITEM WHERE L_ORDER_KEY=${arr[0]}"
    echo $del_sql1 >> dss/updates/$sql_name
    echo $del_sql2 >> dss/updates/$sql_name
    IFS="$OLD_IFS"
   done < $i
done
