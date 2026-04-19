# # -----------------------------
# # 📊 DATA SOURCE (DEFAULT VPC)
# # -----------------------------
# data "aws_vpc" "default" {
#   default = true
# }

# # -----------------------------
# # 🛡️ GUARDDUTY
# # -----------------------------
# resource "aws_guardduty_detector" "main" {
#   enable = true

#   datasources {
#     s3_logs {
#       enable = true
#     }

#     kubernetes {
#       audit_logs {
#         enable = true
#       }
#     }

#     malware_protection {
#       scan_ec2_instance_with_findings {
#         ebs_volumes {
#           enable = true
#         }
#       }
#     }
#   }
# }

# # -----------------------------
# # 🛡️ SECURITY HUB
# # -----------------------------
# resource "aws_securityhub_account" "main" {}

# resource "aws_securityhub_standards_subscription" "cis" {
#   standards_arn = "arn:aws:securityhub:::ruleset/cis-aws-foundations-benchmark/v/1.2.0"
# }

# # -----------------------------
# # ⚙️ AWS CONFIG (IAM ROLE)
# # -----------------------------
# resource "aws_iam_role" "config_role" {
#   name = "aws-config-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Effect = "Allow"
#       Principal = {
#         Service = "config.amazonaws.com"
#       }
#       Action = "sts:AssumeRole"
#     }]
#   })
# }

# resource "aws_iam_role_policy_attachment" "config_policy" {
#   role       = aws_iam_role.config_role.name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
# }

# # -----------------------------
# # ⚙️ AWS CONFIG (SETUP)
# # -----------------------------
# resource "aws_config_configuration_recorder" "recorder" {
#   name     = "config-recorder"
#   role_arn = aws_iam_role.config_role.arn
# }

# resource "aws_config_delivery_channel" "channel" {
#   name           = "config-channel"
#   s3_bucket_name = var.config_bucket
# }

# resource "aws_config_configuration_recorder_status" "status" {
#   name       = aws_config_configuration_recorder.recorder.name
#   is_enabled = true

#   depends_on = [
#     aws_config_delivery_channel.channel
#   ]
# }

# # -----------------------------
# # 📜 CLOUDTRAIL (S3 BUCKET)
# # -----------------------------
# resource "aws_s3_bucket" "cloudtrail_logs" {
#   bucket        = "${var.project_name}-cloudtrail-logs"
#   force_destroy = true
# }

# resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_encryption" {
#   bucket = aws_s3_bucket.cloudtrail_logs.id

#   rule {
#     apply_server_side_encryption_by_default {
#       sse_algorithm = "AES256"
#     }
#   }
# }

# # -----------------------------
# # 📜 CLOUDTRAIL POLICY (IMPORTANT)
# # -----------------------------
# resource "aws_s3_bucket_policy" "cloudtrail_policy" {
#   bucket = aws_s3_bucket.cloudtrail_logs.id

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Sid    = "AWSCloudTrailWrite"
#         Effect = "Allow"
#         Principal = {
#           Service = "cloudtrail.amazonaws.com"
#         }
#         Action   = "s3:PutObject"
#         Resource = "${aws_s3_bucket.cloudtrail_logs.arn}/*"
#       }
#     ]
#   })
# }

# # -----------------------------
# # 📜 CLOUDTRAIL
# # -----------------------------
# resource "aws_cloudtrail" "main" {
#   name                          = "cloudtrail-logging"
#   s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
#   include_global_service_events = true
#   is_multi_region_trail         = true
#   enable_logging                = true
# }

# # -----------------------------
# # 🌐 VPC FLOW LOGS
# # -----------------------------
# resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
#   name              = "/aws/vpc/flowlogs"
#   retention_in_days = 30
# }

# resource "aws_iam_role" "flow_logs_role" {
#   name = "vpc-flow-logs-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Effect = "Allow"
#       Principal = {
#         Service = "vpc-flow-logs.amazonaws.com"
#       }
#       Action = "sts:AssumeRole"
#     }]
#   })
# }

# resource "aws_iam_role_policy" "flow_logs_policy" {
#   role = aws_iam_role.flow_logs_role.id

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Effect = "Allow"
#       Action = [
#         "logs:CreateLogStream",
#         "logs:PutLogEvents"
#       ]
#       Resource = "*"
#     }]
#   })
# }

# resource "aws_flow_log" "vpc_flow_logs" {
#   log_destination      = aws_cloudwatch_log_group.vpc_flow_logs.arn
#   log_destination_type = "cloud-watch-logs"
#   traffic_type         = "ALL"
#   iam_role_arn         = aws_iam_role.flow_logs_role.arn
#   vpc_id               = data.aws_vpc.default.id
# }

# # -----------------------------
# # 🌍 DNS QUERY LOGGING
# # -----------------------------
# resource "aws_cloudwatch_log_group" "dns_logs" {
#   name              = "/aws/route53/dns"
#   retention_in_days = 30
# }

# resource "aws_route53_resolver_query_log_config" "dns_query_logs" {
#   name            = "dns-query-logs"
#   destination_arn = aws_cloudwatch_log_group.dns_logs.arn
# }

# resource "aws_route53_resolver_query_log_config_association" "dns_assoc" {
#   resolver_query_log_config_id = aws_route53_resolver_query_log_config.dns_query_logs.id
#   resource_id                  = data.aws_vpc.default.id
# }


# -----------------------------
# 📊 DATA SOURCE
# -----------------------------
data "aws_vpc" "default" {
  default = true
}

# -----------------------------
# 🔐 KMS KEYS
# -----------------------------
resource "aws_kms_key" "main" {
  description             = "Main security KMS key"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

# -----------------------------
# 🛡️ GUARDDUTY
# -----------------------------
resource "aws_guardduty_detector" "main" {
  enable = true
}

# -----------------------------
# 🛡️ SECURITY HUB
# -----------------------------
resource "aws_securityhub_account" "main" {}

resource "aws_securityhub_standards_subscription" "cis" {
  standards_arn = "arn:aws:securityhub:::ruleset/cis-aws-foundations-benchmark/v/1.2.0"
}

# -----------------------------
# ⚙️ AWS CONFIG
# -----------------------------
resource "aws_iam_role" "config_role" {
  name = "aws-config-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "config.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "config_policy" {
  role       = aws_iam_role.config_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_config_configuration_recorder" "recorder" {
  name     = "config-recorder"
  role_arn = aws_iam_role.config_role.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "channel" {
  name           = "config-channel"
  s3_bucket_name = var.config_bucket
}

resource "aws_config_configuration_recorder_status" "status" {
  name       = aws_config_configuration_recorder.recorder.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.channel]
}

# -----------------------------
# 📦 S3 - CLOUDTRAIL BUCKET
# -----------------------------
resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket        = "${var.project_name}-cloudtrail-logs"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "cloudtrail_versioning" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail_block" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_enc" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.main.arn
    }
  }
}

# -----------------------------
# 📜 CLOUDTRAIL LOG GROUP + SNS
# -----------------------------
resource "aws_cloudwatch_log_group" "cloudtrail_logs" {
  name              = "/aws/cloudtrail/logs"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.main.arn
}

resource "aws_sns_topic" "cloudtrail_alerts" {
  name = "cloudtrail-alerts"
}

resource "aws_iam_role" "cloudtrail_role" {
  name = "cloudtrail-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

# -----------------------------
# 📜 CLOUDTRAIL
# -----------------------------
resource "aws_cloudtrail" "main" {
  name                          = "cloudtrail-logging"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_logging                = true

  enable_log_file_validation = true
  kms_key_id                = aws_kms_key.main.arn

  cloud_watch_logs_group_arn = aws_cloudwatch_log_group.cloudtrail_logs.arn
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_role.arn

  sns_topic_name = aws_sns_topic.cloudtrail_alerts.name
}

# -----------------------------
# 🌐 VPC FLOW LOGS
# -----------------------------
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/flowlogs"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.main.arn
}

resource "aws_iam_role" "flow_logs_role" {
  name = "vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "flow_logs_policy" {
  role = aws_iam_role.flow_logs_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "${aws_cloudwatch_log_group.vpc_flow_logs.arn}:*"
    }]
  })
}

resource "aws_flow_log" "vpc_flow_logs" {
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs.arn
  log_destination_type = "cloud-watch-logs"
  traffic_type         = "ALL"
  iam_role_arn         = aws_iam_role.flow_logs_role.arn
  vpc_id               = data.aws_vpc.default.id
}

# -----------------------------
# 🌍 DNS LOGS
# -----------------------------
resource "aws_cloudwatch_log_group" "dns_logs" {
  name              = "/aws/route53/dns"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.main.arn
}