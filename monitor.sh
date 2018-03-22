#!/bin/bash
LOCKFILE=/tmp/lock.txt
if [ -e ${LOCKFILE} ] && kill -0 `cat ${LOCKFILE}`; then
    echo "already running"
    exit
fi
trap "rm -f ${LOCKFILE}; exit" INT TERM EXIT
echo $$ > ${LOCKFILE}



echo "Checking if yarn local dir requires resizing"

EC2_AVAIL_ZONE=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone`
EC2_REGION="`echo \"$EC2_AVAIL_ZONE\" | sed -e 's:\([0-9][0-9]*\)[a-z]*\$:\\1:'`"
INSTANCE_ID=`curl -s http://169.254.169.254/latest/meta-data/instance-id`

export PATH=$PATH:/sbin/

remaining_size=`df --output=avail /mnt/yarn | sed 1d`
if [ $remaining_size -le 9216000 ]; then
	echo "extending disk"
	CURR_SIZE=`df -B 1g --output=size /mnt/yarn/  | sed 1d `
	NEW_SIZE=$((CURR_SIZE+CURR_SIZE))
	DEVICE_ID=/dev/sd`pvs |  grep yarn_vg |sort | tail -1 | awk ' {print $1}'  | sed 's/\/dev\/sd//' | tr "0-9a-z" "1-9a-z_"`
	VOLUME_ID=`aws ec2 create-volume --availability-zone $EC2_AVAIL_ZONE --volume-type gp2 --region $EC2_REGION --size $NEW_SIZE --tag-specifications "ResourceType=volume,Tags=[{Key=attached_to,Value=$INSTANCE_ID}]" | grep "VolumeId" | sed 's/,//g' | sed 's/"//g' | awk ' { print $2}'`
	until aws ec2 describe-volumes --volume-ids $VOLUME_ID --region $EC2_REGION | jq ".Volumes[0].State" | grep -q available
	do
		echo "EBS not ready yet"
		sleep 1
	done
	aws ec2 attach-volume --volume-id $VOLUME_ID --instance-id $INSTANCE_ID --device $DEVICE_ID --region $EC2_REGION
	sleep 3
	vgextend yarn_vg $DEVICE_ID
	lvextend -l 100%FREE /dev/mapper/yarn_vg-lv_yarn_localdir
	resize2fs /dev/mapper/yarn_vg-lv_yarn_localdir

fi

rm -f ${LOCKFILE}