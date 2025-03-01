# Gets the latest AL2023 EKS AMI with GPU support
data "aws_ami" "eks_gpu_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["Amazon Linux 2023 (x86_64) Nvidia (AL2023_x86_64_NVIDIA)*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["amazon"]
}

# Gets the latest regular AWS EKS AMI
data "aws_ami" "eks_al2_ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amazon-eks-node-${local.cluster_version}-*"]
  }

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

module "vllm-eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.cluster_name
  cluster_version = local.cluster_version

  cluster_endpoint_public_access = true

  cluster_addons = {
    coredns = {
      most_recent       = true
      resolve_conflicts = "OVERWRITE"
    }
    kube-proxy = {
      most_recent       = true
      resolve_conflicts = "OVERWRITE"
    }
    vpc-cni = {
      most_recent       = true
      resolve_conflicts = "OVERWRITE"
    }
    aws-ebs-csi-driver = {
      most_recent              = true
      resolve_conflicts        = "OVERWRITE"
      service_account_role_arn = aws_iam_role.ebs_csi_driver_role.arn
    }
  }

  # Networking
  vpc_id                      = module.vpc.vpc_id
  subnet_ids                  = module.vpc.private_subnets
  control_plane_subnet_ids    = module.vpc.private_subnets
  cluster_security_group_name = "vllm-eks-cluster"
  node_security_group_name    = "vllm-eks-nodes"

  node_security_group_additional_rules = {
    alb_ingress = {
      description              = "Access from Ingress ALBs"
      protocol                 = "tcp"
      from_port                = 8080
      to_port                  = 8080
      type                     = "ingress"
      source_security_group_id = aws_security_group.open-webui-ingress-sg.id
    }
  }

  # EKS Managed Node Groups
  eks_managed_node_groups = {
    router = {
      # Number of instances to deploy
      min_size     = 1
      max_size     = 1
      desired_size = 1

      # AMI and instance type
      ami_id         = data.aws_ami.eks_al2_ami.id
      instance_types = ["m5a.large"]
      capacity_type  = "ON_DEMAND"

      disk_size = 20
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 20
            volume_type           = "gp3"
            delete_on_termination = true
          }
        }
      }

      # Adds IAM permissions to node role
      create_iam_role = true
      iam_role_name   = "router-eks-node-group"
      iam_role_additional_policies = {
        AmazonALBIngressController   = aws_iam_policy.aws_load_balancer_controller.arn
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }

      # User data bootstraps EKS node and installs AWS CLI
      pre_bootstrap_user_data = <<-EOT
      #!/bin/bash
      /etc/eks/bootstrap.sh ${local.cluster_name}
      EOT

      # Adds Kubernetes labels used for pod placement
      node_group_labels = {
        "app" = "vllm-router"
      }

      tags = {
        "kubernetes.io/cluster/${local.cluster_name}" = "owned"
      }
    }

    vllm-inference = {
      # Number of instances to deploy
      min_size     = 1
      max_size     = 1
      desired_size = 1

      # AMI and instance type
      ami_id         = data.aws_ami.eks_gpu_ami.id
      instance_types = ["g5.xlarge"]
      capacity_type  = "ON_DEMAND"

      # Adds IAM permissions to node role
      create_iam_role = true
      iam_role_name   = "vllm-inference-eks-node-group"
      iam_role_additional_policies = {
        AmazonALBIngressController   = aws_iam_policy.aws_load_balancer_controller.arn
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }

      # Adds a disk large enough to store models
      disk_size = 100
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 100
            volume_type           = "gp3"
            delete_on_termination = true
          }
        }
      }

      # User data bootstraps EKS node
      pre_bootstrap_user_data = <<-EOT
      #!/bin/bash
      /etc/eks/bootstrap-gpu-nvidia.sh
      /etc/eks/bootstrap.sh ${local.cluster_name}
      EOT

      tags = {
        "kubernetes.io/cluster/${local.cluster_name}" = "owned"
      }

      # Adds Kubernetes labels used for pod placement
      node_group_labels = {
        "app" = "vllm-inference"
      }
    }
  }

  # To add the current caller identity as an administrator
  enable_cluster_creator_admin_permissions = true
}
