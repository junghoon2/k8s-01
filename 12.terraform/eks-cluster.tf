provider "aws" {
  region = local.region
}

locals {
  name            = "kr-dev-eks"
  cluster_version = "1.22"
  region          = "ap-northeast-2"

  tags = {
    user       = "jerry" 
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.14.0"

  name                 = local.name
  cidr                 = "10.0.0.0/16"

  azs                  = ["${local.region}a", "${local.region}b", "${local.region}c"]

  private_subnets      = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  public_subnets       = ["10.0.104.0/24", "10.0.105.0/24", "10.0.106.0/24"]

  create_egress_only_igw          = true
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  tags = local.tags

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.name}" = "shared"
    "kubernetes.io/role/elb"              = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.name}" = "shared"
    "kubernetes.io/role/internal-elb"     = 1
  }
}

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "18.21.0"

  cluster_name    = local.name
  cluster_version = local.cluster_version

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  vpc_id          = module.vpc.vpc_id
  # subnet_ids      = ["module.vpc.public_subnets", "module.vpc.private_subnets"]
  subnet_ids      = module.vpc.private_subnets

  cluster_addons = {
    coredns = {
      resolve_conflicts = "OVERWRITE"
    }
    kube-proxy = {}
    vpc-cni = {
      resolve_conflicts = "OVERWRITE"
      service_account_role_arn = module.vpc_cni_irsa.iam_role_arn
    }
  }

  # Extend cluster security group rules
  cluster_security_group_additional_rules = {
    egress_nodes_ephemeral_ports_tcp = {
      description                = "To node 1025-65535"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "egress"
      source_node_security_group = true
    }
  }

  # Extend node-to-node security group rules
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      # ipv6_cidr_blocks = ["::/0"]
    }
  }

  eks_managed_node_group_defaults = {
    instance_types          = ["t3.large"]

    disable_api_termination = false
    enable_monitoring       = true

    metadata_options = {
      http_tokens    = "optional"
      http_endpoint  = "enabled"
    }
    # We are using the IRSA created below for permissions 
    # However, we have to deploy with the policy attached FIRST (when creating a fresh cluster) 
    # and then turn this off after the cluster/node group is created. Without this initial policy, 
    # the VPC CNI fails to assign IPs and nodes cannot join the cluster 
    # See https://github.com/aws/containers-roadmap/issues/1666 for more context 
    
    # iam_role_attach_cni_policy = false
    iam_role_attach_cni_policy = true

    ebs_optimized           = true
    block_device_mappings = {
      xvda = {
        device_name = "/dev/xvda"
        ebs = {
          volume_size           = 100
          volume_type           = "gp3"
          iops                  = 3000
          throughput            = 150
          # encrypted             = true
          # kms_key_id            = aws_kms_key.ebs.arn
          delete_on_termination = true
        }
      }
    }
    tags = local.tags
  }

  eks_managed_node_groups = {
    default = {      
      ami_type      = "AL2_x86_64"

      create_launch_template = true
      launch_template_name   = ""


      instance_types = ["t3.large", "m6i.large"]
      capacity_type  = "SPOT"

      subnet_ids = module.vpc.private_subnets

      min_size     = 2
      max_size     = 5
      desired_size = 2
    }

  }
}

# resource "aws_iam_role_policy_attachment" "additional" {
#   for_each = module.eks.eks_managed_node_groups

#   policy_arn = aws_iam_policy.node_additional.arn
#   role       = each.value.iam_role_name
# }

module "vpc_cni_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name_prefix      = "vpc_cni"
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }

  tags = local.tags
}

