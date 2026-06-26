# IAM Role for EKS Control Plane   ====================================================>
resource "aws_iam_role" "eks_cluster" {
  name = "${var.project_name}-eks-cluster-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "eks.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# IAM Role for Node Group          ====================================================>
resource "aws_iam_role" "eks_nodes" {
  name = "${var.project_name}-eks-nodes-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" } }]
  })
}
# workernode policy communicate with API server ,join to cluster 
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy" 
}

# Needed for VPC CNI plugin responsible for pod networking
resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# Needed for ECR read-only access so that worker nodes can pull container images
resource "aws_iam_role_policy_attachment" "ecr_read_only" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# IAM policy for EBS CSI Driver Needed for PVCs 
resource "aws_iam_role_policy_attachment" "ebs_csi_policy" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# EKS Cluster =======================================================================>

resource "aws_eks_cluster" "main" {
  name     = "${var.project_name}-eks"
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = false
    endpoint_public_access  = true                            #cluster accessible form internet
    public_access_cidrs     = var.eks_public_access_cidrs     #Restricts who can access API.
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"      #aws-auth ConfigMap AND EKS Access Entries
    bootstrap_cluster_creator_admin_permissions = true                      #The Terraform user becomes cluster admin automatically.
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]         #Ensures role policy attached before cluster creation.
}

# Launch template — enables IMDS for EBS CSI pod credential access
resource "aws_launch_template" "eks_nodes" {
  name_prefix = "${var.project_name}-node-"

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "optional"
    http_put_response_hop_limit = 2   # allows pods to reach IMDS
  }

  tag_specifications {
    resource_type = "instance"
    tags = { Name = "${var.project_name}-node" }
  }
}

# EKS Node Group
resource "aws_eks_node_group" "main" {              #Creates managed worker nodes.
  cluster_name    = aws_eks_cluster.main.name       #Attach to cluster.
  node_group_name = "${var.project_name}-ng"
  node_role_arn   = aws_iam_role.eks_nodes.arn      #Node IAM role.
  subnet_ids      = var.private_subnet_ids          #Nodes stay private.
  instance_types  = var.node_instance_types

  launch_template {                                 #Uses custom template created earlier.
    id      = aws_launch_template.eks_nodes.id
    version = aws_launch_template.eks_nodes.latest_version  #Uses latest version.
  }

  scaling_config {
    desired_size = var.node_group_desired
    max_size     = var.node_group_max
    min_size     = var.node_group_min
  }

  update_config { max_unavailable = 1 }

  labels = { role = "worker", project = var.project_name }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.ecr_read_only,
    aws_iam_role_policy_attachment.ebs_csi_policy,
  ]
}

# EBS CSI Driver Addon — auto picks correct version for cluster
data "aws_eks_addon_version" "ebs_csi" {
  addon_name         = "aws-ebs-csi-driver"              #AWS storage driver.
  kubernetes_version = aws_eks_cluster.main.version      #Match cluster version.
  most_recent        = true                              #Use latest supported version.
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = data.aws_eks_addon_version.ebs_csi.version
  resolve_conflicts_on_create = "OVERWRITE"             #If addon already exists:Replace it
  resolve_conflicts_on_update = "OVERWRITE"             #Updates existing addon.

  depends_on = [
    aws_eks_node_group.main,
    aws_iam_role_policy_attachment.ebs_csi_policy,
  ]
}
