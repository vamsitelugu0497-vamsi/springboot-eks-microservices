terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.cluster_name}-db-subnet-group"
  subnet_ids = var.private_subnet_ids
  tags       = var.tags
}

resource "aws_security_group" "rds" {
  name_prefix = "${var.cluster_name}-rds-"
  vpc_id      = var.vpc_id
  description = "Allow Postgres traffic from EKS nodes"

  ingress {
    description = "Postgres from VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "random_password" "master" {
  length  = 20
  special = false
}

resource "aws_secretsmanager_secret" "db_credentials" {
  for_each = toset(var.database_names)
  name     = "${var.cluster_name}/${each.value}/credentials"
  tags     = var.tags
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  for_each  = aws_secretsmanager_secret.db_credentials
  secret_id = each.value.id
  secret_string = jsonencode({
    username = "postgres"
    password = random_password.master.result
    host     = aws_db_instance.main[each.key].address
    port     = 5432
    dbname   = each.key
  })
}

resource "aws_db_instance" "main" {
  for_each = toset(var.database_names)

  identifier             = "${var.cluster_name}-${each.value}"
  engine                 = "postgres"
  engine_version         = "16.3"
  instance_class         = var.instance_class
  allocated_storage      = var.allocated_storage
  max_allocated_storage  = var.max_allocated_storage
  storage_type           = "gp3"
  storage_encrypted      = true

  db_name  = replace(each.value, "-", "_")
  username = "postgres"
  password = random_password.master.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  multi_az                = var.multi_az
  backup_retention_period = var.backup_retention_period
  deletion_protection     = var.deletion_protection
  skip_final_snapshot     = !var.deletion_protection
  final_snapshot_identifier = "${var.cluster_name}-${each.value}-final"

  performance_insights_enabled = true
  monitoring_interval          = 60
  monitoring_role_arn          = var.rds_monitoring_role_arn

  tags = var.tags
}
