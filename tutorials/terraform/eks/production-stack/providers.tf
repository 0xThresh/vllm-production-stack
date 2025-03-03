provider "aws" {
  profile = "default"
  region  = "us-west-2"
}

data "terraform_remote_state" "local" {
  backend = "local"
  config = {
    path = "../eks-infrastructure/terraform.tfstate"
  }
}

provider "helm" {
  kubernetes {
    host                   = data.terraform_remote_state.local.outputs.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(data.terraform_remote_state.local.outputs.eks_cluster_ca_certificate)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.local.outputs.eks_cluster_name, "--output", "json"]
    }
  }
}
