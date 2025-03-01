# Deploying Production Stack on EKS With Terraform

This tutorial covers how to deploy an AWS EKS cluster, and how to deploy vLLM Production Stack on top of it. It makes use of the
Terraform AWS and Helm providers so that the entire workflow can occur within Terraform, and give you a way to track the current
state of both your vLLM Production Stack deployment, and its underlying infrastructure.

## Prerequisites

This tutorial assumes that you already have:

1. An AWS account set up, including an AWS access key configured on your local machine.
2. A basic understanding of AWS networking (including VPCs and security groups) and Kubernetes concepts.
3. A basic understanding of how Terraform and Helm work.
4. [Helm](https://helm.sh/docs/intro/install/) and [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) installed on your machine.

## Deployed Resources

This tutorial has two folders, `eks-infrastructure` and `production-stack`. The resources that are deployed in each folder are described in the next two sections.

### EKS Infrastructure

`eks-infrastructure` contains the Terraform code to deploy the following resources:

- VPC with private and public subnets, and a NAT gateway
- EKS cluster with two worker groups, one without GPU and one with NVIDIA GPUs

### Production Stack

`production-stack` contains the Terraform code that uses the [Terraform Helm provider](https://registry.terraform.io/providers/hashicorp/helm/latest/docs) to provision
the Production Stack Helm chart, including the following resources:

- vLLM deployment hosting OpenAI-compatible endpoint with the `` model deployed
- Router deployment to route requests to models deployed on the EKS cluster, with Ingress enabled

Additionally, two other management services are deployed:

- The [NVIDIA Device Plugin](https://github.com/NVIDIA/k8s-device-plugin) is deployed to allow Kubernetes to expose NVIDIA GPU resources to the vLLM pods.
- The [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.11/) is deployed to allow an AWS ALB to be built to
provision access to the vLLM router from outside the EKS cluster to enable calling the models from anywhere.

## Step-by-Step Tutorial

In order to build the resources in this tutorial, follow the instructions in this section.

### Clone the Repo

Start by cloning the Production Stack repo and setting your working directory to the folder below:

```bash
git@github.com:vllm-project/production-stack.git
cd tutorials/terraform/eks/eks-infrastructure
```

### Update the Region

### Deploy the VPC and EKS Cluster

### Validate the Cluster

### Deploy the NVIDIA Device Plugin, AWS Load Balancer Controller, and Production Stack

### Run Inference Against vLLM From Your Local Machine
