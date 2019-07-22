if [ ! -n "$1" ] ;then
  echo "you must input factor"
  exit;
fi
SF=$1
mkdir dss/queries
for q in `seq 1 22`
do
    DSS_DIST=../../tpch_tools/218/dists.dss  DSS_QUERY=dss/templates ../../tpch_tools/218/qgen -s $SF $q > dss/queries/$q.sql
    sed 's/^select/explain select/' dss/queries/$q.sql > dss/queries/$q.explain.sql
done
