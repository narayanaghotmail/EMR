#!/bin/bash

clusterid=$(cat /mnt/var/lib/info/extraInstanceData.json | grep jobFlowId  | awk -F\" '{print $4}')
type=$(grep -i instanceRole /mnt/var/lib/info/extraInstanceData.json | awk -F\" '{print $4}')

core_cluster_count=$1
volume_tag=$2
bucket_name=$3
vertica_ebs_size=$4
vertica_rpm=$5

echo "core_cluster_count" $core_cluster_count "volume_tag "$volume_tag "bucket_name "$3 "vertica_ebs_size"$4 " verica rpm package "$5 > /tmp/bootstrap.log
if [[ $type == 'CORE' ]];
	then 
		echo "core node found, proceeding for bootstrap action...." >> /tmp/bootstrap.log
		aws s3 cp s3://"$bucket_name"/temp/bootstrap-action/bootstrap.sh  /tmp/bootstrap.sh --region us-east-1
		sudo chmod +x /tmp/bootstrap.sh
		sudo chown root:root /tmp/bootstrap.sh
		echo "calling bootstrap" >> /tmp/bootstrap.log
		echo sh /tmp/bootstrap.sh $clusterid $core_cluster_count $volume_tag $bucket_name >> /tmp/bootstrap.log
		sudo  sh /tmp/bootstrap.sh $clusterid $core_cluster_count $volume_tag $bucket_name $vertica_ebs_size $vertica_rpm
		echo "done " >> /tmp/bootstrap.log
else 
echo "Nothing to do as this is master node." >> /tmp/bootstrap.log
fi 
