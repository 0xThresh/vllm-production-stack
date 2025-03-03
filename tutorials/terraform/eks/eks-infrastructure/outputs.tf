output "eks_cluster_ca_certificate" {
    description = "EKS cluster CA certificate"
    value = module.vllm-eks.cluster_certificate_authority_data
}

output "eks_cluster_endpoint" {
    description = "EKS cluster endpoint"
    value = module.vllm-eks.cluster_endpoint
}

output "eks_cluster_name" {
    description = "EKS cluster name"
    value = module.vllm-eks.cluster_name
}

output "ingress_sg_id" {
    description = "vLLM ingress security group ID"
    value = aws_security_group.vllm-ingress-sg.id
}
