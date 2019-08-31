#!/bin/bash

# Set some sensible defaults
export CORE_CONF_fs_defaultFS=${CORE_CONF_fs_defaultFS:-hdfs://`hostname -f`:8020}

function addProperty() {
  local path=$1
  local name=$2
  local value=$3

  local entry="<property><name>$name</name><value>${value}</value></property>"
  local escapedEntry=$(echo $entry | sed 's/\//\\\//g')
  sed -i "/<\/configuration>/ s/.*/${escapedEntry}\n&/" $path
}

function configure() {
    local module=$1
    local envPrefix=$2

    local var
    local value

    echo "Configuring $module"
    for c in `printenv | perl -sne 'print "$1 " if m/^${envPrefix}_(.+?)=.*/' -- -envPrefix=$envPrefix`; do
        name=`echo ${c} | perl -pe 's/___/-/g; s/__/@/g; s/_/./g; s/@/_/g;'`
        var="${envPrefix}_${c}"
        value=${!var}
        echo " - Setting $name=$value"
        addProperty ${HADOOP_CONF_DIR}/$module-site.xml $name "$value"
    done
}

configure core CORE_CONF
configure hdfs HDFS_CONF
configure yarn YARN_CONF
configure httpfs HTTPFS_CONF
configure kms KMS_CONF
configure mapred MAPRED_CONF

if [ "$MULTIHOMED_NETWORK" = "1" ]; then
    echo "Configuring for multihomed network"

    # HDFS
    addProperty ${HADOOP_CONF_DIR}/hdfs-site.xml dfs.namenode.rpc-bind-host 0.0.0.0
    addProperty ${HADOOP_CONF_DIR}/hdfs-site.xml dfs.namenode.servicerpc-bind-host 0.0.0.0
    addProperty ${HADOOP_CONF_DIR}/hdfs-site.xml dfs.namenode.http-bind-host 0.0.0.0
    addProperty ${HADOOP_CONF_DIR}/hdfs-site.xml dfs.namenode.https-bind-host 0.0.0.0
    addProperty ${HADOOP_CONF_DIR}/hdfs-site.xml dfs.client.use.datanode.hostname true
    addProperty ${HADOOP_CONF_DIR}/hdfs-site.xml dfs.datanode.use.datanode.hostname true

    # YARN
    addProperty ${HADOOP_CONF_DIR}/yarn-site.xml yarn.resourcemanager.bind-host 0.0.0.0
    addProperty ${HADOOP_CONF_DIR}/yarn-site.xml yarn.nodemanager.bind-host 0.0.0.0
    addProperty ${HADOOP_CONF_DIR}/yarn-site.xml yarn.nodemanager.bind-host 0.0.0.0
    addProperty ${HADOOP_CONF_DIR}/yarn-site.xml yarn.timeline-service.bind-host 0.0.0.0

    # MAPRED
    addProperty ${HADOOP_CONF_DIR}/mapred-site.xml yarn.nodemanager.bind-host 0.0.0.0
fi

function wait_for_it()
{
    local serviceport=$1
    local service=${serviceport%%:*}
    local port=${serviceport#*:}
    local retry_seconds=5
    local max_try=100
    let i=1

    nc -z $service $port
    result=$?

    until [ $result -eq 0 ]; do
      echo "[$i/$max_try] check for ${service}:${port}..."
      echo "[$i/$max_try] ${service}:${port} is not available yet"
      if (( $i == $max_try )); then
        echo "[$i/$max_try] ${service}:${port} is still not available; giving up after ${max_try} tries. :/"
        exit 1
      fi

      echo "[$i/$max_try] try in ${retry_seconds}s once again ..."
      let "i++"
      sleep $retry_seconds

      nc -z $service $port
      result=$?
    done
    echo "[$i/$max_try] $service:${port} is available."
}

for i in ${SERVICE_PRECONDITION[@]}
do
    wait_for_it ${i}
done

case "${HADOOP_ROLE}" in
  namenode)
    namedir=`echo $HDFS_CONF_dfs_namenode_name_dir | perl -pe 's#file://##'`
    if [ ! -d $namedir ]; then
      mkdir -p $namedir
    fi

    if [ -z "$CLUSTER_NAME" ]; then
      echo "Cluster name not specified"
      exit 2
    fi

    if [ "`ls -A $namedir`" == "" ]; then
      echo "Formatting namenode name directory: $namedir"
      $HADOOP_HOME/bin/hdfs --config $HADOOP_CONF_DIR namenode -format $CLUSTER_NAME 
    fi

    $HADOOP_HOME/bin/hdfs --config $HADOOP_CONF_DIR namenode
    ;;

  datanode)
    datadir=`echo $HDFS_CONF_dfs_datanode_data_dir | perl -pe 's#file://##'`
    if [ ! -d $datadir ]; then
      mkdir -p $datadir
    fi

    $HADOOP_HOME/bin/hdfs --config $HADOOP_CONF_DIR datanode
    ;;

  resourcemanager)
    $HADOOP_HOME/bin/yarn --config $HADOOP_CONF_DIR resourcemanager
    ;;

  nodemanager)
    $HADOOP_HOME/bin/yarn --config $HADOOP_CONF_DIR nodemanager
    ;;

  historyserver)
    $HADOOP_HOME/bin/yarn --config $HADOOP_CONF_DIR historyserver
    ;;

  *)
    echo "Usage: $0 {datanode|historyserver|namenode|nodemanager|resourcemanager}"
    exit 1
    ;;
esac

