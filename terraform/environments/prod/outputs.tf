output "cluster_endpoint"      { value = module.eks.cluster_endpoint }
output "cluster_name"          { value = module.eks.cluster_name }
output "ecr_repository_url"    { value = aws_ecr_repository.hotstar.repository_url }
output "vpc_id"                { value = module.vpc.vpc_id }
