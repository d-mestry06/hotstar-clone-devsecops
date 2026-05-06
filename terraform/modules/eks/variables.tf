variable "project_name"        {}
variable "cluster_version"     {}
variable "vpc_id"              {}
variable "private_subnet_ids"  { type = list(string) }
variable "node_instance_types" { type = list(string) }
variable "node_group_min"      { type = number }
variable "node_group_max"      { type = number }
variable "node_group_desired"  { type = number }
variable "eks_public_access_cidrs" { type = list(string); default = ["0.0.0.0/0"]; description = "CIDRs allowed to reach EKS public endpoint. Restrict to your IP in production." }
