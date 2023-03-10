output "eks_node_group_role_arn" {
  description = "ARN of the worker nodes IAM role"
  value       = coalesce(var.node_role_arn, join("", aws_iam_role.default.*.arn))
}

output "eks_node_group_role_name" {
  description = "Name of the worker nodes IAM role"
  value       = join("", aws_iam_role.default.*.name)
}

output "eks_node_group_id" {
  description = "EKS Cluster name and EKS Node Group name separated by a colon"
  value       = join("", aws_eks_node_group.default.*.id)
}

output "eks_node_group_arn" {
  description = "Amazon Resource Name (ARN) of the EKS Node Group"
  value       = join("", aws_eks_node_group.default.*.arn)
}

output "eks_node_group_resources" {
  description = "List of objects containing information about underlying resources of the EKS Node Group"
  value       = aws_eks_node_group.default.*.resources
}

output "eks_node_group_status" {
  description = "Status of the EKS Node Group"
  value       = join("", aws_eks_node_group.default.*.status)
}

# output that can be used to force module dependency
output "eks_cluster_name" {
  value       = var.cluster_name
  description = "The name of the EKS cluster."
}
# vim: ts=2 sw=2 et
