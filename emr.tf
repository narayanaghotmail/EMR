
resource "aws_s3_bucket_object" "wrapper_bootstrap_scripts" {
  key = "/temp/bootstrap-action/wrapper_script.sh"
  bucket = "${var.bucket_name}"
  source = "${path.module}/wrapperscript.sh"
}

resource "aws_s3_bucket_object" "bootstrap_scripts" {
  key = "/temp/bootstrap-action/bootstrap.sh"
  bucket = "${var.bucket_name}"
  source = "${path.module}/bootstrap.sh"
}


resource "aws_s3_bucket_object" "vertica_rpm" {
  key = "/vertica/${var.vertica_rpm}"
  bucket = "${var.bucket_name}"
  source = "${path.module}/${var.vertica_rpm}"
}

resource "aws_emr_cluster" "cluster" {
  name          = "${var.emr_name}"
  release_label = "${var.emr_release_lable}"
  applications  = ["Hadoop"]



  termination_protection            = true
  keep_job_flow_alive_when_no_steps = true
  
  

  ec2_attributes {
    subnet_id                         = "${var.subnet_ids}"
	emr_managed_master_security_group ="${aws_security_group.emr-master-sg.id}"
    emr_managed_slave_security_group  = "${aws_security_group.emr-slave-sg.id}"
	service_access_security_group     ="${aws_security_group.emr-service-access-sg.id}"
	instance_profile                  = "${aws_iam_instance_profile.emr_profile.arn}"
	key_name ="${var.key_name}"
  }

  master_instance_group {
	instance_type = "${var.master_instance_type}"
	instance_count = "${var.master_instance_count}"
	
	 ebs_config {
      size                 = "${var.master_instance_ebs_size}"
      type                 = "${var.master_instance_ebs_type}"
      volumes_per_instance = 1
    }
  }
  
   bootstrap_action {
    path = "s3://${var.bucket_name}/temp/bootstrap-action/wrapper_script.sh"
    name = "Custom Action"
    args = ["${var.core_instance_count}","${var.environment}","${var.bucket_name}","${var.vertica_ebs_size}","${var.vertica_rpm}"]
  }
  
 

  core_instance_group {
	instance_type  = "${var.core_instance_type}"
    instance_count = "${var.core_instance_count}"
    ebs_config {
      size                 = "${var.core_instance_ebs_size}"
      type                 = "${var.core_instance_ebs_type}"
      volumes_per_instance = 1
    }

    
  }

  ebs_root_volume_size = "${var.ebs_root_volumne_size}"

  tags = {
    Environment  = "${var.environment}"
	Grade       = "${var.grade}"
	Executer ="${var.executer}"
  }
  
  configurations_json = <<EOF
  [
    {
      "Classification": "hdfs-site",
		"Properties": {
            "dfs.replication": "${var.replication}"
          }
            
    }
  ]
EOF

service_role = "${aws_iam_role.iam_emr_service_role.arn}"
depends_on = ["aws_s3_bucket_object.wrapper_bootstrap_scripts", "aws_s3_bucket_object.bootstrap_scripts", "aws_s3_bucket_object.vertica_rpm"]
 
}

/* Security group for EMR Master instances */
resource "aws_security_group" "emr-master-sg" {
  name = "${var.environment}-emr-master-sg"

  tags {
    Name = "${var.environment}-emr-master-sg"
    Grade = "${var.grade}"
  }

  description = "Open all required ports for App instance to communicate with other instances."
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["10.0.0.0/8"]
  }

  ingress {
    from_port   = 50070
    to_port     = 50070
    protocol    = "TCP"
    cidr_blocks = ["10.0.0.0/8"]
  }

  ingress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "TCP"
    cidr_blocks = ["10.0.0.0/8"]
  }

  ingress {
    from_port   = 50470
    to_port     = 50470
    protocol    = "TCP"
    cidr_blocks = ["10.0.0.0/8"]
  }

  ingress {
    from_port   = 8020
    to_port     = 8020
    protocol    = "TCP"
    cidr_blocks = ["10.0.0.0/8"]
  }

  ingress {
    from_port   = 5433
    to_port     = 5433
    protocol    = "TCP"
    cidr_blocks = ["10.0.0.0/8"]
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


/* Security group for EMR Slave instances */
resource "aws_security_group" "emr-slave-sg" {
  name = "${var.environment}-emr-slave-sg"

  tags {
    Name = "${var.environment}-emr-slave-sg"
    Grade = "${var.grade}"
  }

  description = "Open all required ports for App instance to communicate with other instances."
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["10.0.0.0/8"]
  }
  
  ingress {
    from_port   = 50075
    to_port     = 50075
    protocol    = "TCP"
    cidr_blocks = ["10.0.0.0/8"]
  }
  
    ingress {
    from_port   = 50010
    to_port     = 50010
    protocol    = "TCP"
    cidr_blocks = ["10.0.0.0/8"]
  }
  ingress {
    from_port   = 5433
    to_port     = 5433
    protocol    = "TCP"
    cidr_blocks = ["10.0.0.0/8"]
  }

 ingress {
    from_port   = 5450
    to_port     = 5450
    protocol    = "TCP"
    cidr_blocks = ["10.0.0.0/8"]
  }
  
  ingress {
    from_port   = 50070
    to_port     = 50070
    protocol    = "TCP"
    cidr_blocks = ["10.0.0.0/8"]
  }

  ingress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "TCP"
    cidr_blocks = ["10.0.0.0/8"]
  }

  ingress {
    from_port   = 50470
    to_port     = 50470
    protocol    = "TCP"
    cidr_blocks = ["10.0.0.0/8"]
  }

  ingress {
    from_port   = 8020
    to_port     = 8020
    protocol    = "TCP"
    cidr_blocks = ["10.0.0.0/8"]
  }

  ingress {
    from_port   = 5433
    to_port     = 5433
    protocol    = "TCP"
    cidr_blocks = ["10.0.0.0/8"]
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["10.0.0.0/8"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


/* Security group for EMR service access group */
resource "aws_security_group" "emr-service-access-sg" {
  name = "${var.environment}-emr-service-access-sg"

  tags {
    Name = "${var.environment}-emr-service-access-sg"
    Grade = "${var.grade}"
  }

  description = "Open all required ports for App instance to communicate with other instances."
  vpc_id      = "${var.vpc_id}"

  egress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "TCP"
    security_groups = ["${aws_security_group.emr-slave-sg.id}", "${aws_security_group.emr-master-sg.id}"]
  }
}


resource "aws_iam_role" "iam_emr_service_role" {
  name = "${var.environment}-iam_emr_service_role"

  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "elasticmapreduce.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "iam_emr_service_policy" {
  name = "${var.environment}-iam_emr_service_policy"
  role = "${aws_iam_role.iam_emr_service_role.id}"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [{
        "Effect": "Allow",
        "Resource": "*",
        "Action": [
            "ec2:AuthorizeSecurityGroupEgress",
            "ec2:AuthorizeSecurityGroupIngress",
            "ec2:CancelSpotInstanceRequests",
            "ec2:CreateNetworkInterface",
            "ec2:CreateSecurityGroup",
            "ec2:CreateTags",
            "ec2:DeleteNetworkInterface",
            "ec2:DeleteSecurityGroup",
            "ec2:DeleteTags",
            "ec2:DescribeAvailabilityZones",
            "ec2:DescribeAccountAttributes",
            "ec2:DescribeDhcpOptions",
            "ec2:DescribeInstanceStatus",
            "ec2:DescribeInstances",
            "ec2:DescribeKeyPairs",
            "ec2:DescribeNetworkAcls",
            "ec2:DescribeNetworkInterfaces",
            "ec2:DescribePrefixLists",
            "ec2:DescribeRouteTables",
            "ec2:DescribeSecurityGroups",
            "ec2:DescribeSpotInstanceRequests",
            "ec2:DescribeSpotPriceHistory",
            "ec2:DescribeSubnets",
            "ec2:DescribeVpcAttribute",
            "ec2:DescribeVpcEndpoints",
            "ec2:DescribeVpcEndpointServices",
            "ec2:DescribeVpcs",
            "ec2:DetachNetworkInterface",
            "ec2:ModifyImageAttribute",
            "ec2:ModifyInstanceAttribute",
            "ec2:RequestSpotInstances",
            "ec2:RevokeSecurityGroupEgress",
            "ec2:RunInstances",
            "ec2:TerminateInstances",
            "ec2:DeleteVolume",
            "ec2:DescribeVolumeStatus",
            "ec2:DescribeVolumes",
            "ec2:DetachVolume",
			"ec2:CreateVolume",
            "iam:GetRole",
            "iam:GetRolePolicy",
            "iam:ListInstanceProfiles",
            "iam:ListRolePolicies",
            "iam:PassRole",
            "s3:CreateBucket",
            "s3:Get*",
            "s3:List*",
            "sdb:BatchPutAttributes",
            "sdb:Select",
            "sqs:CreateQueue",
            "sqs:Delete*",
            "sqs:GetQueue*",
            "sqs:PurgeQueue",
            "sqs:ReceiveMessage"
        ]
    }]
}
EOF
}

resource "aws_iam_role" "iam_emr_profile_role" {
  name = "${var.environment}-iam_emr_profile_role"

  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}
resource "aws_iam_instance_profile" "emr_profile" {
  name = "${var.environment}-emr_profile"
  role = "${aws_iam_role.iam_emr_profile_role.name}"
}

resource "aws_iam_role_policy" "iam_emr_profile_policy" {
  name = "${var.environment}-iam_emr_profile_policy"
  role = "${aws_iam_role.iam_emr_profile_role.id}"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [{
        "Effect": "Allow",
        "Resource": "*",
        "Action": [
            "cloudwatch:*",
            "dynamodb:*",
            "ec2:Describe*",
			"ec2:DescribeVolumes",
			"ec2:DescribeAvailabilityZones",
			"ec2:CreateVolume",
			"ec2:DescribeInstances",
			"ec2:AttachVolume",
			"ec2:DescribeVolumeAttribute",
			"ec2:DescribeVolumeStatus",
			"ec2:DetachVolume",
			"ec2:DeleteVolume",
			"ec2:EnableVolumeIO",
			"ec2:CreateTags",
			"ec2:DescribeVolumesModifications",
            "elasticmapreduce:Describe*",
            "elasticmapreduce:ListBootstrapActions",
            "elasticmapreduce:ListClusters",
            "elasticmapreduce:ListInstanceGroups",
            "elasticmapreduce:ListInstances",
            "elasticmapreduce:ListSteps",
            "kinesis:CreateStream",
            "kinesis:DeleteStream",
            "kinesis:DescribeStream",
            "kinesis:GetRecords",
            "kinesis:GetShardIterator",
            "kinesis:MergeShards",
            "kinesis:PutRecord",
            "kinesis:SplitShard",
            "rds:Describe*",
            "s3:*",
            "sdb:*",
            "sns:*",
            "sqs:*"
        ]
    }]
}
EOF
}

