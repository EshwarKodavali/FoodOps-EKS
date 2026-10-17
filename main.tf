# ============================================================
# AWS PROVIDER
# ============================================================

provider "aws" {
  region = "us-east-1"
}


# ============================================================
# VPC
# ============================================================

resource "aws_vpc" "foodops_eks_vpc" {

  cidr_block = "10.0.0.0/16"

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "FoodOps-EKS-VPC"
  }
}


# ============================================================
# PUBLIC SUBNET 1
# ============================================================

resource "aws_subnet" "public_1" {

  vpc_id = aws_vpc.foodops_eks_vpc.id

  cidr_block = "10.0.1.0/24"

  availability_zone = "us-east-1a"

  map_public_ip_on_launch = true

  tags = {
    Name = "FoodOps-EKS-Public-1"
  }
}


# ============================================================
# PUBLIC SUBNET 2
# ============================================================

resource "aws_subnet" "public_2" {

  vpc_id = aws_vpc.foodops_eks_vpc.id

  cidr_block = "10.0.2.0/24"

  availability_zone = "us-east-1b"

  map_public_ip_on_launch = true

  tags = {
    Name = "FoodOps-EKS-Public-2"
  }
}


# ============================================================
# INTERNET GATEWAY
# ============================================================

resource "aws_internet_gateway" "foodops_eks_igw" {

  vpc_id = aws_vpc.foodops_eks_vpc.id

  tags = {
    Name = "FoodOps-EKS-IGW"
  }
}


# ============================================================
# ROUTE TABLE
# ============================================================

resource "aws_route_table" "public" {

  vpc_id = aws_vpc.foodops_eks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"

    gateway_id = aws_internet_gateway.foodops_eks_igw.id
  }

  tags = {
    Name = "FoodOps-EKS-Public-Route"
  }
}


# ============================================================
# ROUTE TABLE ASSOCIATION - SUBNET 1
# ============================================================

resource "aws_route_table_association" "public_1" {

  subnet_id = aws_subnet.public_1.id

  route_table_id = aws_route_table.public.id
}


# ============================================================
# ROUTE TABLE ASSOCIATION - SUBNET 2
# ============================================================

resource "aws_route_table_association" "public_2" {

  subnet_id = aws_subnet.public_2.id

  route_table_id = aws_route_table.public.id
}

# ============================================================
# IAM ROLE FOR EKS CLUSTER
# ============================================================

resource "aws_iam_role" "eks_cluster_role" {

  name = "FoodOps-EKS-Cluster-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "eks.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "FoodOps-EKS-Cluster-Role"
  }
}


# ============================================================
# EKS CLUSTER POLICY
# ============================================================

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {

  role = aws_iam_role.eks_cluster_role.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# ============================================================
# EKS CLUSTER
# ============================================================

resource "aws_eks_cluster" "foodops_eks" {

  name = "FoodOps-EKS"

  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {

    subnet_ids = [
      aws_subnet.public_1.id,
      aws_subnet.public_2.id
    ]

  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]

  tags = {
    Name = "FoodOps-EKS"
  }
}

# ============================================================
# IAM ROLE FOR EKS WORKER NODES
# ============================================================

resource "aws_iam_role" "eks_node_role" {

  name = "FoodOps-EKS-Node-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "FoodOps-EKS-Node-Role"
  }
}


# ============================================================
# WORKER NODE POLICY
# ============================================================

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {

  role = aws_iam_role.eks_node_role.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}


# ============================================================
# ECR CONTAINER REGISTRY POLICY
# ============================================================

resource "aws_iam_role_policy_attachment" "eks_ecr_policy" {

  role = aws_iam_role.eks_node_role.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}


# ============================================================
# CNI NETWORKING POLICY
# ============================================================

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {

  role = aws_iam_role.eks_node_role.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# ============================================================
# EKS MANAGED WORKER NODE GROUP
# ============================================================

resource "aws_eks_node_group" "foodops_nodes" {

  cluster_name = aws_eks_cluster.foodops_eks.name

  node_group_name = "FoodOps-Worker-Nodes"

  node_role_arn = aws_iam_role.eks_node_role.arn

  subnet_ids = [
    aws_subnet.public_1.id,
    aws_subnet.public_2.id
  ]

  # Keep the learning setup small
  instance_types = ["t3.small"]

  # Start with one worker node
  scaling_config {
    desired_size = 1
    min_size     = 1
    max_size     = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_ecr_policy,
    aws_iam_role_policy_attachment.eks_cni_policy
  ]

  tags = {
    Name = "FoodOps-EKS-Worker"
  }
}

# ============================================================
# ECR REPOSITORY
# ============================================================

resource "aws_ecr_repository" "foodops" {

  name = "foodops-v2"

  force_delete = true

  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "FoodOps-V2-ECR"
  }
}

# ============================================================
# ECR LIFECYCLE POLICY
# ============================================================

resource "aws_ecr_lifecycle_policy" "foodops" {

  repository = aws_ecr_repository.foodops.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1

        description = "Keep only the latest 5 images"

        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 5
        }

        action = {
          type = "expire"
        }
      }
    ]
  })
}