# Deploying Production Stack on EKS With Terraform

This tutorial covers how to deploy an AWS EKS cluster, and how to deploy vLLM Production Stack on top of it. It makes use of the
Terraform AWS and Helm providers so that the entire workflow can occur within Terraform, and give you a way to track the current
state of both your vLLM Production Stack deployment, and its underlying infrastructure.

## Prerequisites

This tutorial assumes that you already have:

1. An AWS account set up, including an AWS access key configured on your local machine.
2. A basic understanding of AWS networking (including VPCs and security groups) and Kubernetes concepts.
3. A basic understanding of how Terraform and Helm work.
4. [Helm](https://helm.sh/docs/intro/install/), [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli), [Kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl), and [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) installed on your machine.

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
```

### Update the Providers

In the `eks-infrastructure/providers.tf` file, update the AWS provider to use your preferred profile name if you're using a profile name other than `default` for your AWS credentials. Also update the region to use your preferred AWS region; it is set to `us-west-2` by default.

Make the same updates in the `production-stack/providers.tf` file. With these updates complete, you're ready to start deploying resources!

### Deploy the VPC and EKS Cluster

From the root of the Production Stack project, run the following command to navigate to the first folder we'll build resources from:

```bash
cd tutorials/terraform/eks/eks-infrastructure
```

Use the commands below to initialize Terraform, and to prepare to build the infrastructure:

```bash
terraform init
terraform plan
```

If everything is set up correctly, you should now see a Terraform plan, with the plan output ending with the lines below:

```bash
Plan: 80 to add, 0 to change, 0 to destroy.
```

If you're ready to build the resources, you can run:

```bash
terraform apply
```

The plan will be executed again, and you should see the dialogue below:

```bash
Plan: 80 to add, 0 to change, 0 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value:
```

Type `yes` and hit enter to start building the VPC and EKS cluster. The full deployment process often takes 30-40 minutes.

### Validate the Cluster

When the apply completes, you should see the message below:

```bash
Apply complete! Resources: 80 added, 0 changed, 0 destroyed.
```

This confirms that the AWS VPC and EKS cluster were built successfully. You can now add the EKS cluster's context to Kubectl by running the following command:

```bash
aws eks update-kubeconfig --name vllm-cluster
```

This allows you to start running `kubectl` commands against your new cluster. To make sure that the management services are all running as expected, and to make sure that at least two nodes are present in the cluster, run the commands below:

```bash
kubectl get pods -A
kubectl get nodes
```

You should see output similar to below:

```bash
NAMESPACE     NAME                                  READY   STATUS    RESTARTS   AGE
kube-system   aws-node-qs6nj                        2/2     Running   0          4h2m
kube-system   aws-node-rrwgf                        2/2     Running   0          4h2m
kube-system   coredns-5449774944-2v9x7              1/1     Running   0          5h4m
kube-system   coredns-5449774944-9krsv              1/1     Running   0          5h4m
kube-system   ebs-csi-controller-6f59858cc4-gqscv   6/6     Running   0          4h2m
kube-system   ebs-csi-controller-6f59858cc4-vt7tl   6/6     Running   0          4h2m
kube-system   ebs-csi-node-sclz6                    3/3     Running   0          4h2m
kube-system   ebs-csi-node-t5nms                    3/3     Running   0          4h2m
kube-system   kube-proxy-72ll8                      1/1     Running   0          4h4m
kube-system   kube-proxy-8qc75                      1/1     Running   0          4h3m
...
NAME                                        STATUS   ROLES    AGE    VERSION
ip-10-10-3-149.us-west-2.compute.internal   Ready    <none>   4h3m   v1.32.1-eks-5d632ec
ip-10-10-3-201.us-west-2.compute.internal   Ready    <none>   4h4m   v1.32.1-eks-5d632ec
```

If everything looks as expected, you can move on to the next section to deploy resources through the Terraform Helm provider.

### Deploy the NVIDIA Device Plugin, AWS Load Balancer Controller, and Production Stack

With the cluster deployed, we now need to deploy the NVIDIA Device Plugin, AWS Load Balancer Controller, and finally, the Production Stack. These services are all deployed with their respective Helm charts through Terraform.

From the `eks-infrastructure` folder, run the below command to switch to the `production-stack` folder:

```bash
cd ../production-stack
```

If you're running the command from the root of the project, run the command below instead:

```bash
cd tutorials/terraform/eks/production-stack
```

Use the commands below to initialize Terraform, and to prepare to build the infrastructure:

```bash
terraform init
terraform plan
```

If everything is set up correctly, you should now see a Terraform plan, with the plan output ending with the lines below:

```bash
Plan: 80 to add, 0 to change, 0 to destroy.
```

If you're ready to build the resources, you can run:

```bash
terraform apply
```

The plan will be executed again, and you should see the dialogue below:

```bash
Plan: 80 to add, 0 to change, 0 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value:
```

Type `yes` and hit enter to start building the VPC and EKS cluster. The full deployment process often takes 30-40 minutes.

### Run Inference Against vLLM From Your Local Machine
