#!/bin/bash
INSTANCE_ID=`curl -s http://169.254.169.254/latest/meta-data/instance-id`
EC2_AVAIL_ZONE=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone`
EC2_REGION="`echo \"$EC2_AVAIL_ZONE\" | sed -e 's:\([0-9][0-9]*\)[a-z]*\$:\\1:'`"

# Remove crontab entry for script
curr_cron=`sudo crontab -u root -l | sed '/autoscale_storage/ s/^/#/'`
echo $curr_cron   | sudo crontab -u root -

# While the filesystem isn't umounted
until ! mountpoint -q /mnt/yarn/ 
do
	echo "Inside umount loop"
	sudo fuser -mk /mnt/yarn
	sudo umount /mnt/yarn
	sleep 1
done

sudo vgremove -f  yarn_vg


aws ec2 describe-volumes --filters Name=tag:attached_to,Values=$INSTANCE_ID  --region us-east-1 | jq -r ".Volumes[].VolumeId" | awk " { system(\"aws ec2 detach-volume --force --volume-id \" \$1 \" --region $EC2_REGION \")}"

# Loop until the volumes switched to available
until ! aws ec2 describe-volumes --filters Name=tag:attached_to,Values=$INSTANCE_ID  --region us-east-1 | jq -r ".Volumes[].State" | grep -q in-use
do
	echo "inside loop"
	sleep 1
done

aws ec2 describe-volumes --filters Name=tag:attached_to,Values=$INSTANCE_ID  --region us-east-1 | jq -r ".Volumes[].VolumeId" | awk " { system(\"aws ec2 delete-volume --volume-id \" \$1 \" --region $EC2_REGION \")}"
