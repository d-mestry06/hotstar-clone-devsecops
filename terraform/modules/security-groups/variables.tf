variable "project_name" {}
variable "vpc_id"        {}
variable "vpc_cidr"      {}
variable "allowed_ssh_cidr" {
  default     = "0.0.0.0/0"
  description = "CIDR allowed to SSH into Jenkins. Restrict to your IP in production."
}
