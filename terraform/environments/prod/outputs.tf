output "cluster_endpoint"      { value = module.eks.cluster_endpoint }
output "cluster_name"          { value = module.eks.cluster_name }
output "ecr_repository_url"    { value = aws_ecr_repository.hotstar.repository_url }
output "vpc_id"                { value = data.aws_vpc.main.id }
output "private_subnet_ids"    { value = var.private_subnet_ids }
output "public_subnet_ids"     { value = var.public_subnet_ids }
output "security_group_id"     { value = data.aws_security_group.existing.id }
