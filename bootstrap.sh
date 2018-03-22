#!/bin/bash

IS_MASTER=`curl -s http://169.254.169.254/latest/user-data | jq ".isMaster"`
if [ $IS_MASTER == "true" ]; then 
	echo "Not running on the master"
	exit 0
fi

EC2_AVAIL_ZONE=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone`
EC2_REGION="`echo \"$EC2_AVAIL_ZONE\" | sed -e 's:\([0-9][0-9]*\)[a-z]*\$:\\1:'`"
INSTANCE_ID=`curl -s http://169.254.169.254/latest/meta-data/instance-id`
VOLUME_ID=`aws ec2 create-volume --availability-zone $EC2_AVAIL_ZONE --volume-type gp2 --region $EC2_REGION --size 10 --tag-specifications "ResourceType=volume,Tags=[{Key=attached_to,Value=$INSTANCE_ID}]"| grep "VolumeId" | sed 's/,//g' | sed 's/"//g' | awk ' { print $2}'`


# Wait for ok status 
until aws ec2 describe-volumes --volume-ids $VOLUME_ID --region $EC2_REGION | jq ".Volumes[0].State" | grep -q available
do
	echo "EBS not ready yet"
	sleep 1
done


aws ec2 attach-volume --volume-id $VOLUME_ID --instance-id $INSTANCE_ID --device /dev/sdn --region $EC2_REGION 

# Wait for attachment to complete
until aws ec2 describe-volumes --volume-ids $VOLUME_ID --region $EC2_REGION | jq ".Volumes[0].Attachments[0].State" | grep -q attached
do
	echo "EBS not attached yet"
	sleep 1
done



echo "Creating VG"
sudo vgcreate -f  yarn_vg /dev/sdn 
echo "Creating LV"
sudo lvcreate  -l 100%FREE  yarn_vg -n lv_yarn_localdir
echo "Creating EXT3"
sudo mkfs.ext3 /dev/mapper/yarn_vg-lv_yarn_localdir
echo "Mounting "
sudo mkdir /mnt/yarn
sudo mount -v -t ext3 /dev/mapper/yarn_vg-lv_yarn_localdir /mnt/yarn  &> /tmp/mnt.out
sudo chown -R yarn:yarn /mnt/yarn


sudo mkdir /usr/share/aws/emr/scripts/autoscale_storage
sudo wget https://s3.amazonaws.com/athenasync/autoscale_storage/monitor.sh -O /usr/share/aws/emr/scripts/autoscale_storage/monitor.sh
sudo chmod u+x /usr/share/aws/emr/scripts/autoscale_storage/monitor.sh

sudo wget https://s3.amazonaws.com/athenasync/autoscale_storage/decomission.sh -O /mnt/var/lib/instance-controller/public/shutdown-actions/decomission.sh
sudo chmod au+x /mnt/var/lib/instance-controller/public/shutdown-actions/decomission.sh



cronjob="* * * * * /usr/share/aws/emr/scripts/autoscale_storage/monitor.sh"
curr_cron=`sudo crontab -u root -l`
echo -e $curr_cron '\n' "$cronjob"  | sudo crontab -u root -