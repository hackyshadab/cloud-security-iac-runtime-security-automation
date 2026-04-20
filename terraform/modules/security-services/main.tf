
# variable "admin_account_id" {
#   type    = string
#   default = null
# }

# data "aws_caller_identity" "current" {}

# data "aws_vpc" "default" {
#   default = true
# }

# resource "aws_kms_key" "logs_key" {
#   description             = "KMS key for logs encryption"
#   deletion_window_in_days = 7
#   enable_key_rotation     = true

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Sid    = "RootAccess"
#         Effect = "Allow"
#         Principal = {
#           AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
#         }
#         Action   = "kms:*"
#         Resource = "*"
#       }
#     ]
#   })
# }

# resource "aws_guardduty_detector" "main" {
#   enable                       = true
#   finding_publishing_frequency = "FIFTEEN_MINUTES"
# }

# resource "aws_guardduty_organization_admin_account" "admin" {
#   count = var.admin_account_id != null ? 1 : 0

#   admin_account_id = var.admin_account_id
# }

# resource "aws_guardduty_organization_configuration" "org_config" {
#   count = var.admin_account_id != null ? 1 : 0

#   detector_id = aws_guardduty_detector.main.id
#   auto_enable_organization_members = "ALL"
# }


# resource "aws_sns_topic" "cloudtrail_alerts" {
#   name              = "cloudtrail-alerts"
#   kms_master_key_id = aws_kms_key.logs_key.arn
# }

# resource "aws_s3_bucket" "access_logs" {
#   bucket = "${var.project_name}-access-logs"
# }

# resource "aws_s3_bucket_versioning" "access_logs_versioning" {
#   bucket = aws_s3_bucket.access_logs.id

#   versioning_configuration {
#     status = "Enabled"
#   }
# }

# resource "aws_s3_bucket_public_access_block" "access_logs_block" {
#   bucket = aws_s3_bucket.access_logs.id

#   block_public_acls       = true
#   block_public_policy     = true
#   ignore_public_acls      = true
#   restrict_public_buckets = true
# }

# resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs_encryption" {
#   bucket = aws_s3_bucket.access_logs.id

#   rule {
#     apply_server_side_encryption_by_default {
#       kms_master_key_id = aws_kms_key.logs_key.arn
#       sse_algorithm     = "aws:kms"
#     }
#   }
# }

# resource "aws_s3_bucket_lifecycle_configuration" "access_logs_lifecycle" {
#   bucket = aws_s3_bucket.access_logs.id

#   rule {
#     id     = "cleanup"
#     status = "Enabled"

#     expiration {
#       days = 90
#     }

#     abort_incomplete_multipart_upload {
#       days_after_initiation = 7
#     }
#   }
# }

# resource "aws_s3_bucket" "cloudtrail_logs" {
#   bucket        = "${var.project_name}-cloudtrail-logs"
#   force_destroy = true
# }

# resource "aws_s3_bucket_versioning" "cloudtrail_versioning" {
#   bucket = aws_s3_bucket.cloudtrail_logs.id

#   versioning_configuration {
#     status = "Enabled"
#   }
# }

# resource "aws_s3_bucket_public_access_block" "cloudtrail_block" {
#   bucket = aws_s3_bucket.cloudtrail_logs.id

#   block_public_acls       = true
#   block_public_policy     = true
#   ignore_public_acls      = true
#   restrict_public_buckets = true
# }

# resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_encryption" {
#   bucket = aws_s3_bucket.cloudtrail_logs.id

#   rule {
#     apply_server_side_encryption_by_default {
#       kms_master_key_id = aws_kms_key.logs_key.arn
#       sse_algorithm     = "aws:kms"
#     }
#   }
# }


# resource "aws_s3_bucket_logging" "cloudtrail_logging" {
#   bucket        = aws_s3_bucket.cloudtrail_logs.id
#   target_bucket = aws_s3_bucket.access_logs.id
#   target_prefix = "cloudtrail/"
# }


# resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail_lifecycle" {
#   bucket = aws_s3_bucket.cloudtrail_logs.id

#   rule {
#     id     = "cleanup"
#     status = "Enabled"

#     expiration {
#       days = 365
#     }

#     abort_incomplete_multipart_upload {
#       days_after_initiation = 7
#     }
#   }
# }

# resource "aws_cloudwatch_log_group" "cloudtrail_logs" {
#   name              = "/aws/cloudtrail/logs"
#   retention_in_days = 365
#   kms_key_id        = aws_kms_key.logs_key.arn
# }


# resource "aws_iam_role" "cloudtrail_role" {
#   name = "cloudtrail-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Effect = "Allow"
#       Principal = {
#         Service = "cloudtrail.amazonaws.com"
#       }
#       Action = "sts:AssumeRole"
#     }]
#   })
# }

# resource "aws_iam_role_policy" "cloudtrail_policy" {
#   role = aws_iam_role.cloudtrail_role.id

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Effect = "Allow"
#       Action = [
#         "logs:CreateLogStream",
#         "logs:PutLogEvents"
#       ]
#       Resource = "${aws_cloudwatch_log_group.cloudtrail_logs.arn}:*"
#     }]
#   })
# }


# resource "aws_cloudtrail" "main" {
#   name                          = "cloudtrail-logging"
#   s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
#   include_global_service_events = true
#   is_multi_region_trail         = true
#   enable_logging                = true

#   enable_log_file_validation = true
#   kms_key_id                 = aws_kms_key.logs_key.arn
#   sns_topic_name             = aws_sns_topic.cloudtrail_alerts.name

#   cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail_logs.arn}:*"
#   cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_role.arn
# }


# resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
#   name              = "/aws/vpc/flowlogs"
#   retention_in_days = 365
#   kms_key_id        = aws_kms_key.logs_key.arn
# }

# resource "aws_iam_role" "flow_logs_role" {
#   name = "flow-logs-role"

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
#       Resource = "${aws_cloudwatch_log_group.vpc_flow_logs.arn}:*"
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


variable "admin_account_id" {
  type    = string
  default = null
}

data "aws_caller_identity" "current" {}

data "aws_vpc" "default" {
  default = true
}

# -----------------------------
# 🔐 KMS KEY FOR LOGS / ALERTS
# -----------------------------
resource "aws_kms_key" "logs_key" {
  description             = "KMS key for logs encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RootAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },

      # ✅ CloudWatch Logs
      {
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"
        Principal = {
          Service = "logs.us-east-1.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },

      # ✅ CloudTrail (IMPORTANT)
      {
        Sid    = "AllowCloudTrail"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey*",
          "kms:Decrypt"
        ]
        Resource = "*"
      },

      # ✅ SNS (VERY IMPORTANT 🔥)
      {
        Sid    = "AllowSNS"
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action = [
          "kms:GenerateDataKey*",
          "kms:Decrypt"
        ]
        Resource = "*"
      },

      {
        Sid    = "AllowLambdaAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/incident-response-role"
        }
        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt"
        ]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------
# 🛡️ GUARDDUTY
# -----------------------------
resource "aws_guardduty_detector" "main" {
  enable                       = true
  finding_publishing_frequency  = "FIFTEEN_MINUTES"
}

resource "aws_guardduty_organization_admin_account" "admin" {
  count = var.admin_account_id != null ? 1 : 0

  admin_account_id = var.admin_account_id
}

resource "aws_guardduty_organization_configuration" "org_config" {
  count = var.admin_account_id != null ? 1 : 0

  detector_id                     = aws_guardduty_detector.main.id
  auto_enable_organization_members = "ALL"
}

# -----------------------------
# 📧 SNS TOPIC FOR ALERTS
# -----------------------------
resource "aws_sns_topic" "cloudtrail_alerts" {
  name              = "cloudtrail-alerts"
  kms_master_key_id = aws_kms_key.logs_key.arn
}

resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.cloudtrail_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# -----------------------------
# 🪣 ACCESS LOG BUCKET
# -----------------------------
resource "aws_s3_bucket" "access_logs" {
  bucket = "${var.project_name}-access-logs"
}

resource "aws_s3_bucket_versioning" "access_logs_versioning" {
  bucket = aws_s3_bucket.access_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "access_logs_block" {
  bucket = aws_s3_bucket.access_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs_encryption" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.logs_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "access_logs_lifecycle" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    id     = "cleanup"
    status = "Enabled"

    expiration {
      days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# -----------------------------
# 🪣 CLOUDTRAIL LOG BUCKET
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

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_encryption" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.logs_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_logging" "cloudtrail_logging" {
  bucket        = aws_s3_bucket.cloudtrail_logs.id
  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "cloudtrail/"
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail_lifecycle" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  rule {
    id     = "cleanup"
    status = "Enabled"

    expiration {
      days = 365
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# -----------------------------
# 📜 CLOUDWATCH LOG GROUP FOR CLOUDTRAIL
# -----------------------------
resource "aws_cloudwatch_log_group" "cloudtrail_logs" {
  name              = "/aws/cloudtrail/logs"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.logs_key.arn
}

resource "aws_iam_role" "cloudtrail_role" {
  name = "cloudtrail-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "cloudtrail.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_s3_bucket_policy" "cloudtrail_policy" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail_logs.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail_logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

resource "aws_sns_topic_policy" "cloudtrail_sns_policy" {
  arn = aws_sns_topic.cloudtrail_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudTrailPublish"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.cloudtrail_alerts.arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "cloudtrail_logs_policy" {
  role = aws_iam_role.cloudtrail_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.cloudtrail_logs.arn}:*"
      }
    ]
  })
}

resource "aws_cloudtrail" "main" {
  name                          = "cloudtrail-logging"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_logging                = true

  enable_log_file_validation = true
  kms_key_id                 = aws_kms_key.logs_key.arn
  # sns_topic_name             = aws_sns_topic.cloudtrail_alerts.name

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail_logs.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_role.arn

  depends_on = [
    aws_sns_topic_policy.cloudtrail_sns_policy,
    aws_iam_role_policy.cloudtrail_logs_policy 
  ]
}

# -----------------------------
# 🌐 VPC FLOW LOGS
# -----------------------------
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/flowlogs"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.logs_key.arn
}

resource "aws_iam_role" "flow_logs_role" {
  name = "flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
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
# 🚨 EVENTBRIDGE RULE FOR GUARDDUTY FINDINGS
# -----------------------------
resource "aws_cloudwatch_event_rule" "guardduty_rule" {
  name        = "guardduty-findings-rule"
  description = "Trigger on GuardDuty findings"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
  })
}

# -----------------------------
# ⚙️ LAMBDA ROLE
# -----------------------------
resource "aws_iam_role" "lambda_role" {
  name = "incident-response-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # ✅ SNS publish
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.cloudtrail_alerts.arn
      },

      # ✅ CloudWatch logs
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },

      # 🔥🔥 ADD THIS (IMPORTANT FIX)
      {
        Effect = "Allow"
        Action = [
          "kms:GenerateDataKey",
          "kms:Decrypt"
        ]
        Resource = aws_kms_key.logs_key.arn
      }
    ]
  })
}

# -----------------------------
# 🧠 LAMBDA FUNCTION
# -----------------------------
resource "aws_lambda_function" "incident_handler" {
  function_name = "incident-handler"
  role          = aws_iam_role.lambda_role.arn
  handler       = "incident_handler.lambda_handler"
  runtime       = "python3.9"

  filename         = "${path.module}/lambda.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda.zip")

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.cloudtrail_alerts.arn
    }
  }
}

# -----------------------------
# 🔗 EVENTBRIDGE → LAMBDA
# -----------------------------
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.guardduty_rule.name
  target_id = "SendToLambda"
  arn       = aws_lambda_function.incident_handler.arn
}


resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.incident_handler.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.guardduty_rule.arn
}