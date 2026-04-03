terraform {
    required_version = ">= 1.0"

    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "~> 5.0"
        }
    }
}

provider "aws" {
    region = "us-east-1"
}

data "aws_availability_zones" "azs" {
    state = "available"
}

resource "aws_vpc" "eks" {
    cidr_block = "10.0.0.0/16"
    tags = {
        Name = "eks-vpc"
    }
}

resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.eks.id
    tags = { Name = "eks-igw" }
}

resource "aws_route_table" "public" {
    vpc_id = aws_vpc.eks.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }
    tags = { Name = "eks-public-rt" }
}

resource "aws_subnet" "public" {
    count                   = 2
    vpc_id                  = aws_vpc.eks.id
    cidr_block              = cidrsubnet(aws_vpc.eks.cidr_block, 8, count.index)
    availability_zone       = data.aws_availability_zones.azs.names[count.index]
    map_public_ip_on_launch = true
    tags = {
        Name = "eks-public-${count.index}"
    }
}

resource "aws_route_table_association" "public" {
    count = 2
    subnet_id      = aws_subnet.public[count.index].id
    route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "eks" {
    name        = "eks-cluster-sg"
    description = "EKS cluster security group"
    vpc_id      = aws_vpc.eks.id
    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        from_port       = 0
        to_port         = 0
        protocol        = "-1"
        self            = true
    }
    tags = { Name = "eks-cluster-sg" }
}

resource "aws_iam_role" "eks_cluster" {
    name = "eks-cluster-role"
    assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume_role.json
}

data "aws_iam_policy_document" "eks_cluster_assume_role" {
    statement {
        actions = ["sts:AssumeRole"]
        principals {
            type        = "Service"
            identifiers = ["eks.amazonaws.com"]
        }
    }
}

resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSClusterPolicy" {
    role       = aws_iam_role.eks_cluster.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}
resource "aws_iam_role_policy_attachment" "eks_cluster_AmazonEKSServicePolicy" {
    role       = aws_iam_role.eks_cluster.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
}

resource "aws_iam_role" "eks_node" {
    name = "eks-node-role"
    assume_role_policy = data.aws_iam_policy_document.eks_node_assume_role.json
}

data "aws_iam_policy_document" "eks_node_assume_role" {
    statement {
        actions = ["sts:AssumeRole"]
        principals {
            type        = "Service"
            identifiers = ["ec2.amazonaws.com"]
        }
    }
}

resource "aws_iam_role_policy_attachment" "eks_node_AmazonEKSWorkerNodePolicy" {
    role       = aws_iam_role.eks_node.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}
resource "aws_iam_role_policy_attachment" "eks_node_AmazonEKS_CNI_Policy" {
    role       = aws_iam_role.eks_node.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}
resource "aws_iam_role_policy_attachment" "eks_node_AmazonEC2ContainerRegistryReadOnly" {
    role       = aws_iam_role.eks_node.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_eks_cluster" "eks" {
    name     = "example-eks"
    role_arn = aws_iam_role.eks_cluster.arn

    vpc_config {
        subnet_ids = aws_subnet.public[*].id
        security_group_ids = [aws_security_group.eks.id]
    }

    depends_on = [
        aws_iam_role_policy_attachment.eks_cluster_AmazonEKSClusterPolicy,
        aws_iam_role_policy_attachment.eks_cluster_AmazonEKSServicePolicy
    ]
}

resource "aws_eks_node_group" "ng" {
    cluster_name    = aws_eks_cluster.eks.name
    node_group_name = "example-eks-ng"
    node_role_arn   = aws_iam_role.eks_node.arn
    subnet_ids      = aws_subnet.public[*].id
    scaling_config {
        desired_size = 2
        max_size     = 3
        min_size     = 1
    }
    instance_types = ["t3.medium"]
    remote_access {
        ec2_ssh_key = "your-ssh-key-name"
    }

    depends_on = [
        aws_iam_role_policy_attachment.eks_node_AmazonEKSWorkerNodePolicy,
        aws_iam_role_policy_attachment.eks_node_AmazonEKS_CNI_Policy,
        aws_iam_role_policy_attachment.eks_node_AmazonEC2ContainerRegistryReadOnly,
        aws_eks_cluster.eks
    ]
}

output "cluster_name" {
    value = aws_eks_cluster.eks.name
}
output "cluster_endpoint" {
    value = aws_eks_cluster.eks.endpoint
}
output "cluster_certificate_authority_data" {
    value = aws_eks_cluster.eks.certificate_authority[0].data
}