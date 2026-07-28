output "eks_cluster_role_arn" {
  value = aws_iam_role.eks_cluster.arn
}

output "eks_node_role_arn" {
  value = aws_iam_role.eks_node.arn
}

output "irsa_role_arns" {
  value = { for k, v in aws_iam_role.irsa : k => v.arn }
}

output "ci_cd_role_arn" {
  value = aws_iam_role.ci_cd.arn
}
