variable "project_name"       {}
variable "vpc_cidr"           {}
variable "availability_zones" { type = list(string) }
variable "private_subnets"    { type = list(string) }
variable "public_subnets"     { type = list(string) }
