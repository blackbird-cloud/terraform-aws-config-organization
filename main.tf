resource "aws_config_organization_conformance_pack" "default" {
  for_each = var.conformance_packs

  name            = each.key
  template_s3_uri = try(each.value.template_s3_uri, null)
  template_body   = try(each.value.template_body, null)
  depends_on      = [aws_config_configuration_recorder.default]
}

resource "aws_config_configuration_recorder" "default" {
  name     = var.name
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_config_configuration_aggregator" "organization" {
  depends_on = [aws_iam_role_policy_attachment.organization]

  name = var.name

  organization_aggregation_source {
    all_regions = true
    role_arn    = aws_iam_role.organization.arn
  }
}

resource "aws_iam_role" "config" {
  name               = "awsconfig-${var.name}"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "config" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_iam_role" "organization" {
  name               = "awsconfig-organization-${var.name}"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "organization" {
  role       = aws_iam_role.organization.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSConfigRoleForOrganizations"
}

data "aws_caller_identity" "default" {}

module "kms_key" {
  source  = "blackbird-cloud/kms-key/aws"
  version = "~> 0"

  name   = var.name
  policy = <<EOF
  {
    "Id": "key-policy-1",
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Enable IAM User Permissions",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::${data.aws_caller_identity.default.account_id}:root"
            },
            "Action": "kms:*",
            "Resource": "*"
        },
        {
            "Sid": "Allow access for Key Administrators",
            "Effect": "Allow",
            "Principal": {
                "AWS": ${jsonencode(var.administrator_arns)}
            },
            "Action": [
                "kms:Create*",
                "kms:Describe*",
                "kms:Enable*",
                "kms:List*",
                "kms:Put*",
                "kms:Update*",
                "kms:Revoke*",
                "kms:Disable*",
                "kms:Get*",
                "kms:Delete*",
                "kms:TagResource",
                "kms:UntagResource",
                "kms:ScheduleKeyDeletion",
                "kms:CancelKeyDeletion"
            ],
            "Resource": "*"
        },
        {
            "Sid": "Allow read access for Key users",
            "Effect": "Allow", 
            "Principal": {
                "AWS": ${jsonencode(var.viewers_arns)}
            }, 
            "Action": [ 
                "kms:Decrypt",
                "kms:GenerateDataKey",
                "kms:DescribeKey"
            ],
            "Resource": "*"
        },
        {
            "Sid": "Allow write access for Key users",
            "Effect": "Allow", 
            "Principal": {
                "AWS": ${jsonencode(var.writers_arns)}
            }, 
            "Action": [ 
                "kms:Encrypt",
                "kms:GenerateDataKey",
                "kms:DescribeKey"
            ],
            "Resource": "*"
        },
        {
            "Sid": "AWSConfig", 
            "Effect": "Allow", 
            "Principal": {
              "Service": ["config.amazonaws.com"],
              "AWS": "${aws_iam_role.config.arn}"
            }, 
            "Action": [ 
                "kms:Encrypt",
                "kms:Decrypt",
                "kms:DescribeKey",
                "kms:GenerateDataKey*"
            ],
            "Resource": "*",
            "Condition": {
              "StringEquals": {
                  "aws:ResourceOrgID": "${data.aws_organizations_organization.default.id}"
              }
            }
        }
    ]
}
EOF
  tags   = var.tags
}

data "aws_organizations_organization" "default" {}

module "bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3"

  bucket_prefix = var.name

  restrict_public_buckets = true
  ignore_public_acls      = true
  block_public_policy     = true
  block_public_acls       = true

  server_side_encryption_configuration = {
    rule = {
      bucket_key_enabled = true
      apply_server_side_encryption_by_default = {
        sse_algorithm     = "aws:kms"
        kms_master_key_id = module.kms_key.kms.arn
      }
    }
  }
  versioning = {
    enabled = true
  }

  lifecycle_rule = [
    {
      id      = "lifecycle-rule-1"
      enabled = true

      transition = [
        {
          days          = 30
          storage_class = "ONEZONE_IA"
        },
        {
          days          = 60
          storage_class = "GLACIER"
        }
      ]

      noncurrent_version_expiration = {
        days = 90
      }
    }
  ]
  tags = var.tags
}

module "bucket_policy" {
  source  = "blackbird-cloud/s3-bucket-policy/aws"
  version = "~> 0"

  s3_bucket_id = module.bucket.s3_bucket_id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AWSConfigPermissions",
      "Effect":"Allow",
      "Action":[
        "s3:GetBucketAcl",
        "s3:ListBucket"
      ],
      "Resource":[
        "${module.bucket.s3_bucket_arn}"
      ],
      "Principal": {
        "Service": ["config.amazonaws.com"]
      },
      "Condition": {
        "StringEquals": {
          "aws:ResourceOrgID": "${data.aws_organizations_organization.default.id}"
        }
      }
    },
    {
      "Effect":"Allow",
      "Action":[
        "s3:PutObject"
      ],
      "Principal": {
        "Service": ["config.amazonaws.com"]
      },
      "Resource":"${module.bucket.s3_bucket_arn}/*",
      "Condition":{
        "StringLike":{
          "s3:x-amz-acl":"bucket-owner-full-control",
          "aws:ResourceOrgID": "${data.aws_organizations_organization.default.id}"
        }
      }
    }
  ]
}
EOF
}

resource "aws_config_delivery_channel" "default" {
  name           = var.name
  s3_bucket_name = module.bucket.s3_bucket_id
}

resource "aws_config_configuration_recorder_status" "default" {
  name       = aws_config_configuration_recorder.default.name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.default]
}

output "bucket" {
  value = module.bucket
}
