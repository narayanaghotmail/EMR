#!/bin/bash
#
##########################################################################
##                                                                                                                                              ##
##                                                                                                                                              ##
##########################################################################
#
#



#clusterid=$(cat /mnt/var/lib/info/extraInstanceData.json | grep jobFlowId  | awk -F\" '{print $4}')

clusterid=$1
core_cluster_count=$2
volume_tag=$3
bucket_name=$4
vertica_ebs_size=$5
vertica_rpm=$6


echo "core_cluster_count--->"$core_cluster_count "volume_tag--->"$volume_tag" bucketName "$bucket_name | tee -a /tmp/bootstrap.log
echo "Start Time:" `date  +%m/%d/%Y\ %H:%M:%S` | tee /tmp/bootstrap.log
currsysip=`/sbin/ifconfig eth0 | grep 'inet addr' | cut -d: -f2 | awk '{print $1}'`
echo "->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>LOG IS FROM "$currsysip" >>>>>>>>>>>>>>>>>>>>>>>>"  | tee -a /tmp/bootstrap.log
echo "inside bootstrap script and cluster id is: "$1  | tee -a /tmp/bootstrap.log

#Define defaults (update as per your project)
declare -a arrAvlVolIntrim
PROJ_DIR="/tmp"
TEMP_DIR="/tmp"
LOG_DIR="/tmp/log"
LOCK_DIR="/tmp/lock"
SCRIPT_NAME=`basename "$0"`
varCurrDtTm=`date +"%Y%m%d%H%M%S"`
varDefLogFile=$SCRIPT_NAME"_"$varCurrDtTm".log"
varTmpRunningInstanceInfoFile=$TEMP_DIR/$SCRIPT_NAME"_RunningInstanceInfo_"$varCurrDtTm".TMP"
#Get total argument count
varGetArgCnt=$#
############################################################################################################
#Funtion for making entry to log file
funcLogEntry()
{
                echo "hey"
    echo "$@"
    echo "$(date '+%F %T')|$@" >> "$LOG_DIR/${varDefLogFile}"
}

############################################################################################################
#Validate if lock file exists.
#Create an empty file if doesn't exist.

funcCheckFileExistnc()
{
if [ -f $1 ];
        then
        funcLogEntry "An instance for ${varTag} is already running."
                return 99
    else
        funcLogEntry "No previous instance for ${varTag} found, triggering the process."
                touch $varTag
fi
}

############################################################################################################
#Get length of array

funcGetLen()
{
varLen=${#arrClustList[@]}
return $varLen
}

############################################################################################################
#Clear array to store next set of variables

funcSSHKey()
{

echo "inside ssh key func " | tee -a /tmp/bootstrap.log
echo "number of bootstraping instaces are:"${#arrIpList[@]} | tee -a /tmp/bootstrap.log
echo "install vertica dependency" | tee -a /tmp/bootstrap.log
funcVerticaPrerequisite
varIP=`/sbin/ifconfig eth0 | grep 'inet addr' | cut -d: -f2 | awk '{print $1}'`
echo " ssh key func Start Time:" `date  +%m/%d/%Y\ %H:%M:%S` | tee -a /tmp/bootstrap.log
varHostName=$1
if [ -f ~/.ssh/id_rsa.pub ];
then
echo "ssh key is already present"  | tee -a /tmp/bootstrap.log
else
echo "generating ssh key." | tee -a /tmp/bootstrap.log
ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
sed -i 's/#PermitRootLogin yes/PermitRootLogin yes/g' /etc/ssh/sshd_config

service sshd restart
echo "sshd service restarted" | tee -a /tmp/bootstrap.log

echo "current system ip " $varIP | tee -a /tmp/bootstrap.log
cd ~/.ssh
cpcmd="aws s3 cp id_rsa.pub s3://"$bucket_name"/temp/sshkesy/"$varIP"_PubKey --region us-east-1" 


echo "cp idrsa cmd" $cpcmd | tee -a /tmp/bootstrap.log
$cpcmd
echo "copy done" | tee -a /tmp/bootstrap.log
sleep 60
fi

for (( i=0; i<$core_cluster_count; i++)) # change here, currently considered only three nodes at max
do
echo "inside copy each other's public key block " | tee -a /tmp/bootstrap.log
echo "remote system ip: " ${arrIpList[$i]} "and current system IP: " "$varIP" | tee -a /tmp/bootstrap.log
if [ ${arrIpList[$i]} != "$varIP" ];
then
echo "remote system Ip" ${arrIpList[$i]} "and current system ip" "$varIP" "did not match hence in further steps we will copy public keys" | tee -a /tmp/bootstrap.log
#echo "list of ips"${arrIpList[$i]} "system ip ""$varIP" | tee -a /tmp/bootstrap.log
if [ -f ~/.ssh/authorized_keys ];
then 
echo "appending publlic key of "${arrIpList[$i]} "to authorized key of " "$varIP" | tee -a /tmp/bootstrap.log
aws s3 cp s3://"$bucket_name"/temp/sshkesy/${arrIpList[$i]}_PubKey /tmp/SSH_${arrIpList[$i]} --region us-east-1
cat /tmp/SSH_${arrIpList[$i]} >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
else 
echo "authorize file does not exists hence adding  public key of "${arrIpList[$i]} "to authorize key file"
mkdir -m 700 -p ~/.ssh
aws s3 cp s3://"$bucket_name"/temp/sshkesy/${arrIpList[$i]}_PubKey /tmp/SSH_${arrIpList[$i]} --region us-east-1
cat /tmp/SSH_${arrIpList[$i]} > ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

fi
fi
done
echo  " ssh key func end Time:" `date  +%m/%d/%Y\ %H:%M:%S` | tee -a /tmp/bootstrap.log

funcCheckVerticaInstallation
}


############################################################################################################
#SSH setup

funcAWSProfileSetup()
{
	echo "inside aws profile setup block " | tee -a /tmp/bootstrap.log
	echo "Start Time:" `date  +%m/%d/%Y\ %H:%M:%S` | tee -a /tmp/bootstrap.log
	if [ -f ~/.aws/config ];
	then
		echo "bypassing aws profile setup"
	else 
		aws s3 cp s3://"$bucket_name"/temp/config ~/.aws/
		aws s3 cp s3://"$bucket_name"/temp/credentials ~/.aws/
	echo "aws key setup finished..." | tee -a /tmp/bootstrap.log
	echo " Aws Setup End Time:" `date  +%m/%d/%Y\ %H:%M:%S` | tee -a /tmp/bootstrap.log
	fi
	
funcGetInstanceInfo
}

funcCheckVerticaInstallation()
{

echo  "funcCheckVerticaInstallation start Time:" `date  +%m/%d/%Y\ %H:%M:%S` | tee -a /tmp/bootstrap.log

verticacnt=0
intrimUpdateVerticaNodes=''
declare -a installedarr
echo "array size " ${#installedarr[@]}
declare -a updatearr
for (( i=0; i<$core_cluster_count; i++)) 
do

#dirExists=`ssh ${arrIpList[$i]}  "ls '/opt/vertica/config' |wc -l"`
echo "checking if vertica setup was done earlier on " ${arrIpList[$i]} "node." | tee -a /tmp/bootstrap.log
#if [ $dirExists -gt 3 ];
if ssh  ${arrIpList[$i]} '[ -d /opt/vertica/config ]' ;
	then
	echo "vertica exists  on -->"${arrIpList[$i]} | tee -a /tmp/bootstrap.log
		((verticacnt=verticacnt+1))
		installedarr=(${arrIpList[$i]} "${installedarr[@]}")
	else 
		echo "vertica does not exists on : "${arrIpList[$i]}
		updatearr=(${arrIpList[$i]} "${updatearr[@]}")
fi 
done
echo "update array size "${#updatearr[@]}
if [ ${#installedarr[@]} != 0 ];
	then 
		echo "vertica is installed "${#installedarr[@]} "node(s)" | tee -a /tmp/bootstrap.log
	else 
		echo "vertica not installed on " ${installedarr[@]} | tr ' ' ',' | tee -a /tmp/bootstrap.log
fi
intrimUpdateVerticaNodes=`echo ${updatearr[@]} | tr ' ' ','`



echo "vertica on node(s):" ${#installedarr[@]} " is already setup " | tee -a /tmp/bootstrap.log

echo  "funcCheckVerticaInstallation end  Time:" `date  +%m/%d/%Y\ %H:%M:%S` | tee -a /tmp/bootstrap.log
if [ ${arrIpList[0]} == "$varIP" ];
	then 
		echo "calling  funcVerticaInstallation block from " ${arrIpList[0]} | tee -a /tmp/bootstrap.log
			funcVerticaInstallation 
fi
}

funcVerticaInstallation()
{
	echo  "funcVerticaInstallation start  Time:" `date  +%m/%d/%Y\ %H:%M:%S` | tee -a /tmp/bootstrap.log
	echo "setup decider: "$verticacnt | tee -a /tmp/bootstrap.log
	
	
	
	
	if [ ${arrIpList[0]} == "$varIP" ]; # THIS CONDITION CAN BE REMOVED
		then
		
			if [ ${#installedarr[@]} == $core_cluster_count ]; # hard coded here
				then 
					echo "Vertica rpm is already present in all the nodes" | tee -a /tmp/bootstrap.log
				else
					if [ ${#updatearr[@]} == $core_cluster_count ];
						then 
							echo "Fresh Vertica Installation " | tee -a /tmp/bootstrap.log
							echo "current user is " 
							whoami
							echo "vertica will be installed on "$intrimUpdateVerticaNodes | tee -a /tmp/bootstrap.log
							echo "Initiating vertica installation from: ""$varIP" | tee -a /tmp/bootstrap.log
							echo "Copying Vertica RPM " | tee -a /tmp/bootstrap.log
							aws s3 cp "s3://"$bucket_name"/vertica/"$vertica_rpm "/home/vericarpm/" --region us-east-1
							
							rpm -Uvh /home/vericarpm/$vertica_rpm
							
							sudo /opt/vertica/sbin/install_vertica --hosts $intrimUpdateVerticaNodes --rpm /home/vericarpm/$vertica_rpm --dba-user dbadmin 2>&1 | tee -a /tmp/bootstrap.log
						else 
							funcVerticaUpdate
					fi
			fi
			
	fi


echo  "funcVerticaInstallation end  Time:" `date  +%m/%d/%Y\ %H:%M:%S` | tee -a /tmp/bootstrap.log
} 

funcVerticaUpdate()
{

echo "Inside Vertica Update Block" | tee -a /tmp/bootstrap.log
echo "Please update new node "$intrimUpdateVerticaNodes "manually. Work in progress!!!" | tee -a /tmp/bootstrap.log
echo "nodes to be updated"$intrimUpdateVerticaNodes | tee -a /tmp/bootstrap.log
						#	echo "adding node to existing cluster.."$intrimUpdateVerticaNodes | tee -a /tmp/bootstrap.log
						#	sudo /opt/vertica/sbin/update_vertica --add-hosts $intrimUpdateVerticaNodes --rpm /home/vericarpm/vertica-9.2.1-1.x86_64.RHEL6.rpm --dba-user dbadmin 2>&1 | tee -a /tmp/bootstrap.log

}

funcVerticaPrerequisite()
{
echo "Inside Vertica Prerequisite block " | tee -a /tmp/bootstrap.log
yum -y install dialog
dd if=/dev/zero of=/var/swapfile bs=1024 count=2097152
chmod 600 /var/swapfile
mkswap /var/swapfile
swapon /var/swapfile

echo "vm.swappiness = 1" >> /etc/sysctl.conf ; echo 1 > /proc/sys/vm/swappiness
df | grep "^/dev/" | awk '{ print "/sbin/blockdev --setra 2048 " $1}' | sh
echo  " Vertica Prerequisite block Ends " | tee -a /tmp/bootstrap.log
}

funcUnsetArray()
{
varArrName=$1
for i in ${!$varArrName[@]}
do
    unset $varArrName[${i}]
done
}

############################################################################################################
#Create array of available volumes

funcAvlblVol()
{
j=1
varLen=`awk '{print gsub(/\t/,"")}' $varTmpAvlVolInfoFile`
for (( i=0; i<$varLen+1; i++))
do
arrAvlVolIntrim[$i]=`awk '{ print $'"$j"'}' $varTmpAvlVolInfoFile`
((j=j+1))
done
}

############################################################################################################
#Get instance info.

funcGetInstanceInfo()
{
	echo "inside funcGetInstanceInfo " | tee -a /tmp/bootstrap.log
	echo "Start Time:" `date  +%m/%d/%Y\ %H:%M:%S` | tee -a /tmp/bootstrap.log
	varClusID=$clusterid
	k=0
	varTmpInstanceInfoFile=$TEMP_DIR/$SCRIPT_NAME"_InstanceInfo_"$varCurrDtTm".TMP"
	varTmpAvlVolInfoFile=$TEMP_DIR/$SCRIPT_NAME"_AvailableVolInfo_"$varCurrDtTm".TMP"
	echo "instance json " | tee -a /tmp/bootstrap.log
	aws emr list-instances --cluster-id $varClusID --instance-group-types CORE --region us-east-1  2>&1 | tee -a /tmp/bootstrap.log
	aws emr list-instances --cluster-id $varClusID --instance-group-types CORE  --instance-states BOOTSTRAPPING --region us-east-1 >$varTmpInstanceInfoFile
	
	# GET INSTANCE IDS
	arrInstncList=($(jq -r '.Instances[].Ec2InstanceId' $varTmpInstanceInfoFile))
	
	# GET IP ADDRESSES
	arrIpList=($(jq -r '.Instances[].PrivateIpAddress' $varTmpInstanceInfoFile))
	
	# MAKE A COMMASEPARATED LIST OF IPS
	arrIpListCommaSep=($(jq -r '.Instances | map(.PrivateIpAddress)| join(",")' $varTmpInstanceInfoFile))

	echo "comma seperated ip adddress: "$arrIpListCommaSep | tee -a /tmp/bootstrap.log
	
	echo "sending control to funcSSHKey " | tee -a /tmp/bootstrap.log
	
	funcSSHKey $arrIpListCommaSep
	
	echo "control is back to funcGetInstanceInfo"  | tee -a /tmp/bootstrap.log
	
	echo "resume time:" `date  +%m/%d/%Y\ %H:%M:%S` | tee -a /tmp/bootstrap.log
	
	varInstcLen=${#arrInstncList[@]}
	
	echo "No of instance(s) "$varInstcLen | tee -a /tmp/bootstrap.log
	
	declare -a arrIntrimInstncList
	for ((i=0; i<$varInstcLen; i++ ))
		do
			aws ec2 describe-instances --instance-ids "${arrInstncList[$i]}" --region us-east-1 >/tmp/instancelist.txt
				# GET THE COUNT OF VOLUMES ATTACHED TO A INSTANCE
				volcnt=`aws ec2 describe-instances --instance-ids "${arrInstncList[$i]}" --query '{id:Reservations[].Instances[].BlockDeviceMappings[].Ebs[]}| length(id[])' --region us-east-1`
				
				echo "volume count in ec2 instance is --------->" "${arrInstncList[$i]}" $volcnt | tee -a /tmp/bootstrap.log
				
			#VOLUME COUNT ON FRESH INSTANCE WILL BE 2
				varCountOfVol=$volcnt

			if [ $varCountOfVol -lt 3 ]
					then
			arrIntrimInstncList[$k]="${arrInstncList[$i]}"
				((k=k+1))

				echo "arrIntrimInstncList" "${arrInstncList[$i]} $i"
			fi
	done
	

			

echo "arrIntrimInstncList " ${#arrIntrimInstncList[@]} | tee -a /tmp/bootstrap.log
varUpdInstcLen=${#arrIntrimInstncList[@]}
echo "varUpdInstcLen: "$varUpdInstcLen | tee -a /tmp/bootstrap.log

k=0

if [ ${arrIpList[0]} == "$currsysip" ];
 then 
        for (( i=0; i<$varUpdInstcLen; i++ ))

       do
			echo "calling function funcCreateVolume for iteration number: "$k "and instance id is :" ${arrIntrimInstncList[$k]} | tee -a /tmp/bootstrap.log
				funcCreateVolume "${arrIntrimInstncList[$k]}"
			
			echo "attach vol to instance inside attach block for --->" "${arrIntrimInstncList[$k]}" | tee -a /tmp/bootstrap.log
			
			echo "attach cmd" aws ec2 attach-volume --volume-id "$generatedvolumeid" --instance-id "${arrIntrimInstncList[$k]}" --device /dev/sdf --region us-east-1 | tee -a /tmp/bootstrap.log
		#ATTACH VOLUME
			aws ec2 attach-volume --volume-id "$generatedvolumeid" --instance-id "${arrIntrimInstncList[$k]}" --device /dev/sdf --region us-east-1
			   sleep 30
		# MOUNT EBS-
			 		echo "Mounting EBS VOLUME ID: "$generatedvolumeid "to Instance ID "${arrIntrimInstncList[$k]} "begins"| tee -a /tmp/bootstrap.log
					
					echo "Formating volume: "$generatedvolumeid | tee -a /tmp/bootstrap.log
					ssh  -o "StrictHostKeyChecking no" ${arrIpList[$i]} ' sudo mkfs -t ext4 /dev/sdf '  2>&1 | tee -a /tmp/bootstrap.log
					
					echo "Mounting Volume: "$generatedvolumeid " to /vertica/data" | tee -a /tmp/bootstrap.log
					ssh  ${arrIpList[$i]} ' sudo mount /dev/sdf /vertica/data/ '  2>&1 | tee -a /tmp/bootstrap.log
					
					echo "Chaning ownership to dbadmin" | tee -a /tmp/bootstrap.log
					ssh  ${arrIpList[$i]} ' sudo chown -R dbadmin:verticadba /vertica/data '  2>&1 | tee -a /tmp/bootstrap.log
					
					echo "Mounting EBS VOLUME ID: "$generatedvolumeid "to Instance ID "${arrIntrimInstncList[$k]} "Ends"| tee -a /tmp/bootstrap.log
               

				((k=k+1))
        done
fi



echo "function funcGetInstanceInfo end Time:" `date  +%m/%d/%Y\ %H:%M:%S` | tee -a /tmp/bootstrap.log

aws s3 cp /tmp/bootstrap.log s3://"$bucket_name"/temp/logs/$currsysip/ --region us-east-1

echo "Copying System Log to "$bucket_name | tee -a /tmp/bootstrap.log
sleep 20
aws s3 cp /emr/instance-controller/log/bootstrap-actions/1/stderr s3://"$bucket_name"/temp/logs/$currsysip/ --region us-east-1
aws s3 cp /emr/instance-controller/log/bootstrap-actions/1/stdout s3://"$bucket_name"/temp/logs/$currsysip/ --region us-east-1
aws s3 cp /emr/instance-controller/log/bootstrap-actions/1/controller s3://"$bucket_name"/temp/logs/$currsysip/ --region us-east-1
echo "log copied to s3" | tee -a /tmp/bootstrap.log

}



funcCreateVolume()
{


 echo "Inside Create volume block " | tee -a /tmp/bootstrap.log
 echo "instance id--->"$1 | tee -a /tmp/bootstrap.log
 echo "value of k create volume time "$k | tee -a /tmp/bootstrap.log
	aws ec2 describe-instances --instance-ids $1 --region us-east-1 > /tmp/$1_instance
	avalibility_zone=($(jq -r '.Reservations[].Instances[0].Placement.AvailabilityZone' /tmp/$1_instance))

#CREATE VOLUME
	echo aws ec2 create-volume --availability-zone "$avalibility_zone" --volume-type gp2 --size $vertica_ebs_size --tag-specifications "ResourceType=volume,Tags=[{Key=Grade,Value='"$volume_tag"'},{Key=Env_Ins,Value='"$1"'},{Key=Name,Value='EBS-"$1"'}]" --dry-run --region us-east-1

	aws ec2 create-volume --availability-zone "$avalibility_zone" --volume-type gp2 --size $vertica_ebs_size --tag-specifications "ResourceType=volume,Tags=[{Key=Grade,Value='"$volume_tag"'},{Key=Env_Ins,Value='"$1"'},{Key=Name,Value='EBS-"$1"'}]" --region us-east-1 >/tmp/$1_instance 2>&1 | tee -a /tmp/bootstrap.log
	
	generatedvolumeid=($(jq -r '.VolumeId' /tmp/"$1_instance"))
	
	echo "Generated volume id for instance:"$1 " is "$generatedvolumeid
	sleep 30
	Env_Ins_Val=$1
echo "craete volume function finished for iteration number " $k | tee -a /tmp/bootstrap.log
}



#IF CLUSTER IS NEW?

funcClusterAlreadyExists()
{
	echo "inside cluster existance check " | tee -a /tmp/bootstrap.log
	echo "Start Time:" `date  +%m/%d/%Y\ %H:%M:%S` | tee -a /tmp/bootstrap.log
	aws emr list-instances --cluster-id $clusterid --instance-group-types CORE  --instance-states RUNNING --region us-east-1 > $varTmpRunningInstanceInfoFile 
arrrunningins=($(jq -r '.Instances[].Ec2InstanceId' $varTmpRunningInstanceInfoFile))

if [ ${#arrrunningins[@]} == 0 ];
then 
{
	echo "New Cluster calling funcGetInstanceInfo function " | tee -a /tmp/bootstrap.log
	funcGetInstanceInfo
}
else 

{
	echo "Cluster is already exists..!!" | tee -a /tmp/bootstrap.log

}

fi


}

#Get cluster info.

funcGetClusterInfo()
{
varTmpClustInfoFile="/temp/ClusterInfo_"$varCurrDtTm".TMP"
aws emr list-clusters --active --region us-east-1 >$varTmpClustInfoFile #should work, try it
arrClustList=($(jq -r '.Clusters[].Id' $varTmpClustInfoFile))

#for i in ${!arrClustList[@]}
#do
#funcGetInstanceInfo("$arrClustList[i]")
#funcGetInstanceInfo("j-3BAGTXQGE3B9D")
#funcGetInstanceInfo("$arrClustList[i]")
#done
}
############################################################################################################
#funcGetClusterInfo

#funcAWSProfileSetup
funcClusterAlreadyExists
#funcGetInstanceInfo


############################################################################################################
