# Builds an AWS VPC with public and private subnets to host vLLM Production Stack infra
module "vllm-vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "vllm-vpc"
  cidr = "10.10.0.0/16"

  azs             = ["${local.region}a", "${local.region}b", "${local.region}c"]
  private_subnets = ["10.10.1.0/24", "10.10.2.0/24", "10.10.3.0/24"]
  public_subnets  = ["10.10.101.0/24", "10.10.102.0/24", "10.10.103.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  # These tags enable the ALB ingress controller to use the public subnets to build an ALB
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
}

# Security group to allow access to Open WebUI
resource "aws_security_group" "vllm-ingress-sg" {
  name   = "vllm-ingress-sg"
  vpc_id = module.vllm-vpc.vpc_id

  ingress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}
