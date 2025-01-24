module "config" {
  source  = "blackbird-cloud/config-organization/aws"
  version = "~> 2"

  s3_bucket_name = "my-bucket"
  role_arn       = "arn:aws:iam::123456789101:role/my-role"
}
