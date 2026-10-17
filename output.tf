# ============================================================
# EKS CLUSTER NAME
# ============================================================

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.foodops_eks.name
}


# ============================================================
# EKS CLUSTER ENDPOINT
# ============================================================

output "eks_cluster_endpoint" {
  description = "Kubernetes API endpoint of the EKS cluster"
  value       = aws_eks_cluster.foodops_eks.endpoint
}


# ============================================================
# EKS NODE GROUP
# ============================================================

output "eks_node_group_name" {
  description = "Name of the EKS worker node group"
  value       = aws_eks_node_group.foodops_nodes.node_group_name
}

# ============================================================
# ECR REPOSITORY URL
# ============================================================

output "ecr_repository_url" {
  description = "ECR repository URL for FoodOps Docker images"
  value       = aws_ecr_repository.foodops.repository_url
}