resource "aws_config_organization_conformance_pack" "default" {
  for_each = var.conformance_packs

  name            = each.key
  template_s3_uri = try(each.value.template_s3_uri, null)
  template_body   = try(each.value.template_body, null)
  depends_on      = [aws_config_configuration_recorder.default]

  timeouts {
    update = "5m"
  }
}

resource "aws_config_configuration_recorder" "default" {
  name     = var.name
  role_arn = var.role_arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_configuration_aggregator" "organization" {
  name = var.name

  organization_aggregation_source {
    all_regions = true
    role_arn    = var.role_arn
  }

  tags = var.tags
}

resource "aws_config_delivery_channel" "default" {
  name           = var.name
  s3_bucket_name = var.s3_bucket_name
  depends_on     = [aws_config_configuration_recorder.default]
}

resource "aws_config_configuration_recorder_status" "default" {
  name       = aws_config_configuration_recorder.default.name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.default]
}
