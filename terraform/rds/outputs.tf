output "db_endpoints" {
  value = { for k, v in aws_db_instance.main : k => v.address }
}

output "secret_arns" {
  value = { for k, v in aws_secretsmanager_secret.db_credentials : k => v.arn }
}
