variable "aws_region"          { default = "ap-south-1" }
variable "project_name"        { default = "hotstar-clone-devsecops" }

# ── Manually created VPC ───────────────────────────────────────────────────
variable "vpc_id" {
  description = "ID of the manually created VPC (e.g. vpc-0abc123)"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs inside the manually created VPC"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs inside the manually created VPC"
  type        = list(string)
}

variable "security_group_id" {
  description = "ID of the manually created security group (e.g. sg-0abc123)"
  type        = string
}

# ── EKS ───────────────────────────────────────────────────────────────
variable "eks_cluster_version" { default = "1.35" }
variable "node_instance_types" { default = ["c7i-flex.large"] }
variable "node_group_min"      { default = 1 }
variable "node_group_max"      { default = 4 }
variable "node_group_desired"  { default = 2 }
