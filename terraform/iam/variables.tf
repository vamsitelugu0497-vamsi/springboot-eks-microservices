variable "cluster_name" {
  type = string
}

variable "namespace" {
  type    = string
  default = "microservices"
}

variable "service_names" {
  type    = list(string)
  default = ["user-service", "product-service", "order-service"]
}

variable "oidc_provider_arn" {
  description = "ARN of the EKS cluster's OIDC provider"
  type        = string
}

variable "oidc_provider_url" {
  description = "URL of the EKS cluster's OIDC provider (no https://)"
  type        = string
}

variable "ci_cd_trusted_principal_arn" {
  description = "ARN of the principal (e.g. Jenkins EC2 instance role) allowed to assume the CI/CD role"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
