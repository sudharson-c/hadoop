#!/bin/bash

# Define variables
HADOOP_VERSION="3.3.6"  # Replace with the desired Hadoop version
HADOOP_URL="https://downloads.apache.org/hadoop/common/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz"
HADOOP_DIR="/usr/local/hadoop"
JAVA_HOME_PATH=$(readlink -f /usr/bin/java | sed "s:/bin/java::")

# Update package repository and install prerequisites
echo "Updating package repository..."
sudo apt update -y
sudo apt install -y ssh pdsh wget tar
sudo apt install openssh-server
sudo systemctl start ssh
sudo systemctl enable ssh

# Download Hadoop
echo "Downloading Hadoop $HADOOP_VERSION..."
wget -q $HADOOP_URL -O hadoop-$HADOOP_VERSION.tar.gz

# Extract Hadoop
echo "Extracting Hadoop..."
sudo tar -xzf hadoop-$HADOOP_VERSION.tar.gz -C /usr/local/
sudo mv /usr/local/hadoop-$HADOOP_VERSION $HADOOP_DIR
rm hadoop-$HADOOP_VERSION.tar.gz

# Set up environment variables
echo "Setting up Hadoop environment variables..."
cat <<EOF | sudo tee -a /etc/profile.d/hadoop.sh
export HADOOP_HOME=$HADOOP_DIR
export PATH=\$PATH:\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin
export JAVA_HOME=$JAVA_HOME_PATH
EOF

source /etc/profile.d/hadoop.sh

# Configure Hadoop
echo "Configuring Hadoop..."
# hadoop-env.sh
sudo sed -i "s|^\# export JAVA_HOME=.*|export JAVA_HOME=$JAVA_HOME_PATH|" $HADOOP_HOME/etc/hadoop/hadoop-env.sh

# core-site.xml
cat <<EOF | sudo tee $HADOOP_HOME/etc/hadoop/core-site.xml
<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://localhost:9000</value>
    </property>
</configuration>
EOF

# hdfs-site.xml
cat <<EOF | sudo tee $HADOOP_HOME/etc/hadoop/hdfs-site.xml
<configuration>
    <property>
        <name>dfs.replication</name>
        <value>1</value>
    </property>
    <property>
        <name>dfs.name.dir</name>
        <value>file:///usr/local/hadoop/data/namenode</value>
    </property>
    <property>
        <name>dfs.data.dir</name>
        <value>file:///usr/local/hadoop/data/datanode</value>
    </property>
</configuration>
EOF

# mapred-site.xml
cat <<EOF | sudo tee $HADOOP_HOME/etc/hadoop/mapred-site.xml
<configuration>
    <property>
        <name>mapreduce.framework.name</name>
        <value>yarn</value>
    </property>
</configuration>
EOF

# yarn-site.xml
cat <<EOF | sudo tee $HADOOP_HOME/etc/hadoop/yarn-site.xml
<configuration>
    <property>
        <name>yarn.nodemanager.aux-services</name>
        <value>mapreduce_shuffle</value>
    </property>
</configuration>
EOF

# Create Hadoop directories for data storage
echo "Creating HDFS directories..."
sudo mkdir -p /usr/local/hadoop/data/namenode
sudo mkdir -p /usr/local/hadoop/data/datanode
sudo chown -R $USER:$USER /usr/local/hadoop/data

# SSH configuration for passwordless login
echo "Configuring SSH for Hadoop..."
ssh-keygen -t rsa -P "" -f ~/.ssh/id_rsa
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
echo "Host localhost
   StrictHostKeyChecking no
" >> ~/.ssh/config

# Format HDFS Namenode
echo "Formatting Namenode..."
hdfs namenode -format

# Start Hadoop services
echo "Starting Hadoop services..."
start-dfs.sh
start-yarn.sh

# Verify Hadoop installation
echo "Verifying Hadoop installation..."
jps

echo "Hadoop installation completed successfully!"
echo "Visit http://localhost:9870 for the Hadoop web UI."
