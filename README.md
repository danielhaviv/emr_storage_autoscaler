# EMR Storage AutoScale Bootstrap Action
A bootstrap action to support automatic growth of storage for EMR worker nodes.

## Usage
1. Create a new IAM policy and attach it to EMR’s IAM role:

    {
    
    "Version": "2012-10-17",
    
    "Statement": \[
    
    {
    
    "Sid": "VisualEditor0",
    
    "Effect": "Allow",
    
    "Action": \[
    
    "ec2:AttachVolume",
    
    "ec2:DescribeVolumes",
    
    "ec2:DetachVolume",
    
    "ec2:DeleteVolume",
    
    "ec2:CreateTags",
    
    "ec2:CreateVolume"
    
    \],
    
    "Resource": "*"
    
    }
    
    \]
    
    }
    

2.  Add the following JSON to configuration pane to set the shuffle directoy:

    \[{"classification":"yarn-site", "properties":{"yarn.nodemanager.local-dirs":"/mnt/yarn"}, "configurations":\[\]}\]

3.  Add the bootstrap action: **s3://athenasync/autoscale_storage/bootstrap.sh**

> Written with [StackEdit](https://stackedit.io/).

