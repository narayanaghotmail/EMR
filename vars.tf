/* Variables */
provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "${var.region}"
}

terraform {
  version = "0.11.8"
  
  required_providers {
    aws = "~> 2.26"
	region  = "us-east-1"
  }
  
  
}

variable "aws_access_key" {
  description = "Enter AWS access key"
}

variable "aws_secret_key" {
  description = "Enter AWS secret key"
}

variable "region" {
  description = "Select the default AWS region for the deployment."
  default ="us-east-1"
}

variable "vpc_id" {
  description = "VPC ID where the deployment is being done"
}


variable "emr_name"
{
	description ="Name of the emr cluster"
	default ="dev-emr"
}

variable "emr_release_lable"
{
	description ="release lable ex: 5.27"
	default ="5.27.0"
}


variable "subnet_ids" {
  description = "subnets id."
  
  
}

variable "key_name"{
	description="ssh key name"
	default ="npemr"
}
variable "master_instance_type"{
	description ="master group instance type ex: m4.large"
	default ="m4.large"
}
variable "master_instance_count"{
	description ="number of master instances ex: 3 for multimaster support"
	default =3
}

variable "master_instance_ebs_size"{
description ="master instance ebs size in gb"
default =10
}

variable "master_instance_ebs_type"{
description ="master instance ebs type ex :gp2"
default ="gp2"
}


variable "bucket_name"{
	description ="provide the bucket name where bootstrap scripts are available ex: nonprodqa-emr"
	default ="aosnp-qa-emr"
}


variable "vertica_ebs_size"{
description ="size of vertica ebs volumes"
default =100
}

variable "vertica_rpm"{
description ="vertica rpm package with verison"
default ="vertica-9.2.1-1.x86_64.RHEL6.rpm"
}

variable "core_instance_type"{
	description ="core group instance type ex :c4.large"
	default ="c4.large"
	
}

variable "core_instance_count"{
	description ="number of core instances ex:3"
	default =3
}

variable "core_instance_ebs_size"{
description ="core instance ebs size ex:5000 gb "
default =500
}

variable "core_instance_ebs_type"{
description ="core instance ebs type ex ST1"
default ="ST1"
}
variable "ebs_root_volumne_size"{
description ="root volume size ex: 10 gb"
default =20
}

variable "environment"{
description = "Environment name ex: awsaos-dev"

}

variable "grade" {
  description = "Type of environment whether it is dev/qa/stg/prod."
  default ="dev"
}

variable "executer" {
	description ="Executer name"
	default="RemoteSwitch"

}
variable "replication" {
description = "Replication factor of data blocks. incase of 3 core instances 2 and incase of 5 core nodes replication will be 3"
default=2
}






