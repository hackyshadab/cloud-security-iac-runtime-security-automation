# -----------------------------
# 📊 VARIABLES
# -----------------------------

variable "admin_account_id" {
  type    = string
  default = null
}

# -----------------------------
# 📊 DATA SOURCES
# -----------------------------
data "aws_caller_identity" "current" {}

data "aws_vpc" "default" {
  default = true
}

# -----------------------------
# 🔐 KMS KEY
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
      }
    ]
  })
}

# -----------------------------
# 🛡️ GUARDDUTY (SAFE)
# -----------------------------
resource "aws_guardduty_detector" "main" {
  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"
}

# Optional (only if org used)
resource "aws_guardduty_organization_admin_account" "admin" {
  count = var.admin_account_id != null ? 1 : 0

  admin_account_id = var.admin_account_id
}

resource "aws_guardduty_organization_configuration" "org_config" {
  count = var.admin_account_id != null ? 1 : 0

  detector_id = aws_guardduty_detector.main.id
  auto_enable_organization_members = "ALL"
}

# -----------------------------
# 🔔 SNS (ENCRYPTED)
# -----------------------------
resource "aws_sns_topic" "cloudtrail_alerts" {
  name              = "cloudtrail-alerts"
  kms_master_key_id = aws_kms_key.logs_key.arn
}

# -----------------------------
# 🪣 ACCESS LOGS BUCKET
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
# 🪣 CLOUDTRAIL BUCKET
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

# ✅ FIX: ACCESS LOGGING ENABLED
resource "aws_s3_bucket_logging" "cloudtrail_logging" {
  bucket        = aws_s3_bucket.cloudtrail_logs.id
  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "cloudtrail/"
}

# ✅ FIX: Lifecycle with abort rule
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
# 📊 CLOUDWATCH
# -----------------------------
resource "aws_cloudwatch_log_group" "cloudtrail_logs" {
  name              = "/aws/cloudtrail/logs"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.logs_key.arn
}

# -----------------------------
# 🔐 IAM ROLE (CLOUDTRAIL)
# -----------------------------
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

resource "aws_iam_role_policy" "cloudtrail_policy" {
  role = aws_iam_role.cloudtrail_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "${aws_cloudwatch_log_group.cloudtrail_logs.arn}:*"
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
  kms_key_id                 = aws_kms_key.logs_key.arn
  sns_topic_name             = aws_sns_topic.cloudtrail_alerts.name

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail_logs.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_role.arn
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
# l
resource "aws_flow_log" "vpc_flow_logs" {
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs.arn
  log_destination_type = "cloud-watch-logs"
  traffic_type         = "ALL"
  iam_role_arn         = aws_iam_role.flow_logs_role.arn
  vpc_id               = data.aws_vpc.default.id
}