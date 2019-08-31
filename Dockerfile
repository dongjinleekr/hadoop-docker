FROM openjdk:8

ARG hadoop_version=3.0.3

LABEL maintainer="Lee Dongjin <dongjin@apache.org>"

ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64/

ENV HADOOP_VERSION $hadoop_version
ENV HADOOP_HOME /opt/hadoop
ENV HADOOP_CONF_DIR $HADOOP_HOME/etc/hadoop
ENV HADOOP_URL https://archive.apache.org/dist/hadoop/core/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz
ENV HDFS_CONF_dfs_namenode_name_dir=file:///hadoop/dfs/name
ENV HDFS_CONF_dfs_datanode_data_dir=file:///hadoop/dfs/data

ENV PATH ${PATH}:${HADOOP_HOME}/bin

ENV MULTIHOMED_NETWORK 1
ENV USER root

COPY start-hadoop.sh /tmp/

RUN set -x \
 && apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    openjdk-8-jdk net-tools curl netcat gnupg \
 && rm -rf /var/lib/apt/lists/* \
 && curl -O https://dist.apache.org/repos/dist/release/hadoop/common/KEYS \
 && gpg --import KEYS \
 && curl -fSL "$HADOOP_URL" -o /tmp/hadoop.tar.gz \
 && curl -fSL "$HADOOP_URL.asc" -o /tmp/hadoop.tar.gz.asc \
 && gpg --verify /tmp/hadoop.tar.gz.asc \
 && tar -xvf /tmp/hadoop.tar.gz -C /opt/ \
 && rm /tmp/hadoop.tar.gz* \
 && ln -s /opt/hadoop-$HADOOP_VERSION $HADOOP_HOME \
 && mv /tmp/start-hadoop.sh /usr/bin \
 && chmod a+x /usr/bin/start-hadoop.sh

# Use "exec" form so that it runs as PID 1 (useful for graceful shutdown)
# 'Role' must be one of: datanode, historyserver, namenode, nodemanager, resourcemanager
CMD ["start-hadoop.sh"]
