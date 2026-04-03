output "cluster_id" {
    description = "The name/id of the EKS cluster"
    value       = aws_eks_cluster.main.id
}

output "cluster_arn" {
    description = "The Amazon Resource Name (ARN) of the cluster"
    value       = aws_eks_cluster.main.arn
}

output "cluster_endpoint" {
    description = "Endpoint for EKS control plane"
    value       = aws_eks_cluster.main.endpoint
}

output "cluster_version" {
    description = "The Kubernetes server version for the cluster"
    value       = aws_eks_cluster.main.version
}

output "cluster_security_group_id" {
    description = "Security group ID attached to the EKS cluster"
    value       = aws_eks_cluster.main.vpc_security_group_ids[0]
}

output "cluster_certificate_authority_data" {
    description = "Base64 encoded certificate data required to communicate with the cluster"
    value       = aws_eks_cluster.main.certificate_authority[0].data
    sensitive   = true
}

output "node_group_id" {
    description = "EKS node group id"
    value       = aws_eks_node_group.main.id
}