# Adds the NVIDIA Device Plugin to enable GPU access on vLLM pods
resource "helm_release" "nvidia_device_plugin" {
  name = "nvidia-device-plugin"

  repository = "https://nvidia.github.io/k8s-device-plugin"
  chart      = "nvidia-device-plugin"
  namespace  = "kube-system"
  version    = "0.17.0"
}


# ALB ingress controller chart
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.7.2"

  set {
    name  = "clusterName"
    value = "genai-cluster"
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
}

# vLLM Production Stack chart
resource "helm_release" "vllm_production_stack" {
  name       = "vllm-production-stack"
  depends_on = [
    helm_release.aws_load_balancer_controller,
    helm_release.nvidia_device_plugin
  ]

  repository       = "https://vllm-project.github.io/production-stack"
  chart            = "vllm-stack"
  namespace        = "vllm"
  create_namespace = true
  version          = "0.0.11"
  values           = [file("${path.module}/values.yaml")]

  set {
    name  = "ingress.annotations.alb\\.ingress\\.kubernetes\\.io/security-groups"
    value = data.terraform_remote_state.local.outputs.ingress_sg_id
  }
}
