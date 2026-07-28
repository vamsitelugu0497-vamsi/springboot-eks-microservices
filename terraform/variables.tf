variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "cluster_name" {
  type    = string
  default = "springboot-eks-cluster"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "kms_key_arn" {
  description = "KMS key used to encrypt EKS secrets"
  type        = string
}

variable "node_instance_types" {
  type    = list(string)
  default = ["m7i-flex.large"]
}

variable "node_desired_size" {
  type    = number
  default = 3
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 6
}

variable "ci_cd_trusted_principal_arn" {
  description = "ARN of the IAM entity (Jenkins EC2 instance role/user) allowed to assume the CI/CD role"
  type        = string
}

variable "rds_monitoring_role_arn" {
  description = "IAM role ARN used by RDS Enhanced Monitoring"
  type        = string
}
