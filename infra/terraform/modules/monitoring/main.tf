module "eks_observability_accelerator" {
  source = "aws-observability/terraform-aws-observability-accelerator/aws"
  version = "~> 2.0"

  aws_region     = var.region
  eks_cluster_id = var.cluster_name

  # This creates AMP workspace + ADOT collector + all scrapers automatically
  enable_managed_prometheus = true
  
  # Optional: Enable specific workload monitoring patterns
  enable_amazon_eks_adot = true
  enable_cert_manager    = true
  enable_kube_state_metrics = true
  
  # Optional: Enable specific integrations
  enable_java  = false
  enable_nginx = false
  enable_gpu_monitoring = true
}