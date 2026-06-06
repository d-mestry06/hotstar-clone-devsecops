output "cluster_endpoint"   { value = aws_eks_cluster.main.endpoint }
output "cluster_name"       { value = aws_eks_cluster.main.name }
output "cluster_ca"         { value = aws_eks_cluster.main.certificate_authority[0].data }
output "node_role_arn"      { value = aws_iam_role.eks_nodes.arn }
output "ebs_csi_version"    { value = aws_eks_addon.ebs_csi.addon_version }
