variable "service_names" {
  type    = list(string)
  default = ["user-service", "product-service", "order-service"]
}

variable "allowed_principal_arns" {
  description = "IAM role ARNs (node role, CI/CD role) permitted to pull/push images"
  type        = list(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}
