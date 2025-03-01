# Edit the values below to match your desired configuration
locals {
  region             = "us-west-2"                                    # Region you want to deploy into
  vpc_name           = "vllm-vpc"                                     # Name of VPC that will be created
  cluster_name       = "vllm-cluster"                                 # Name of the EKS cluster that will be created
  cluster_version    = "1.32"                                         # Version of EKS to use
}
