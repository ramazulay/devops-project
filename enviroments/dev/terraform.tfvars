product_name     = "PROJECT"
company_name     = "CP"
environment      = "dev"
region           = "us-west-1"
azs              = ["us-west-1b", "us-west-1c"]
cidr_block       = "172.80.0.0/16"
route_cidr_block = "0.0.0.0/0"
#cidr_blocks  = [ "172.80.0.1/24", "172.80.0.2/24", "172.80.0.3/24", "172.80.0.4/24" ]


subnets = [
  { name = "subnet-b", cidr = "172.80.1.0/24", azs = "us-west-1b" },
  { name = "subnet-c", cidr = "172.80.2.0/24", azs = "us-west-1c" }
]
public_subnet = [
  { name = "public-subnet-b", cidr = "172.80.5.0/24", azs = "us-west-1b" },
  { name = "public-subnet-c", cidr = "172.80.6.0/24", azs = "us-west-1c" },
]

# EKS
cluster_version  = "1.32"
use_spot_nodes   = true
instance_types   = ["t3.small"]  # t3.small supports 11 pods vs t3.micro's 4 pods
desired_capacity = "2"
min_capacity     = "2"
max_capacity     = "4"  # Increased to allow temporary scaling

addons = [
  {
    name    = "vpc-cni",
    version = "v1.18.3-eksbuild.2"
    attach  = false
  },
  {
    name    = "coredns"
    version = "v1.11.1-eksbuild.13"
    attach  = false
  },
  {
    name    = "kube-proxy"
    version = "v1.30.5-eksbuild.2"
    attach  = false
  },
  { name = "aws-ebs-csi-driver" 
    version = "v1.38.1-eksbuild.1" 
    attach  = false
  }
  # Removed EFS CSI driver - not needed for this project and causes resource issues
  # Add more addons as needed
]


# ECR
repository_name      = "my-app-repo"
image_tag_mutability = "MUTABLE"
scan_on_push         = true

# SQS
sqs_queue_name                = "queue"
sqs_create_dlq                = true
sqs_visibility_timeout_seconds = 30
sqs_message_retention_seconds  = 345600

# S3
s3_bucket_name        = "bucket"
s3_enable_versioning  = true
s3_force_destroy      = false

# KMS
# deletion_window_in_days = 10
# enable_key_rotation     = true
# multi_region            = false