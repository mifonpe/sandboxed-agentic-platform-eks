# --profile is baked in when var.aws_profile is set, rather than telling the
# reader to "be logged in with the correct profile": a command that silently
# targets whatever account the ambient credentials point at is worse than one
# that names the profile. Omitted when the variable is empty, which is the
# ambient-credentials case.
output "configure_kubectl" {
  description = "Configure kubectl: run this to update your kubeconfig"
  value       = "aws eks --region ${var.region}${var.aws_profile != "" ? " --profile ${var.aws_profile}" : ""} update-kubeconfig --name ${module.eks.cluster_name}"
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "kata_namespace" {
  description = "Kata system namespace"
  value       = local.kata_namespace
}

output "agents_namespace" {
  description = "Agent sandbox namespace"
  value       = local.agents_namespace
}
