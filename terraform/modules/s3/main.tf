# -----------------------------
# 🔐 ACCOUNT DATA (FOR KMS POLICY)
# -----------------------------
data "aws_caller_identity" "current" {}

# -----------------------------
# 🪣 MAIN BUCKET
# -----------------------------
resource "aws_s3_bucket" "secure_bucket" {
  bucket = var.bucket_name

  tags = {
    Environment = var.environment
    Owner       = var.owner
    Project     = "cloud-security"
  }
}

# -----------------------------
# ✅ VERSIONING
# -----------------------------
resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.secure_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# -----------------------------
# 🔐 KMS KEY (SECURE POLICY)
# -----------------------------
resource "aws_kms_key" "s3_key" {
  description             = "KMS key for S3 encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAccountAccess"
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
# 🔐 ENCRYPTION (KMS)
# -----------------------------
resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  bucket = aws_s3_bucket.secure_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# -----------------------------
# 🚫 PUBLIC ACCESS BLOCK
# -----------------------------
resource "aws_s3_bucket_public_access_block" "block" {
  bucket = aws_s3_bucket.secure_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# =============================
# 🔐 LOG BUCKET (FULLY SECURED)
# =============================
resource "aws_s3_bucket" "log_bucket" {
  bucket = "${var.bucket_name}-logs"

  tags = {
    Environment = var.environment
    Owner       = var.owner
  }
}

# ✅ LOG BUCKET VERSIONING
resource "aws_s3_bucket_versioning" "log_versioning" {
  bucket = aws_s3_bucket.log_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# ✅ LOG BUCKET ENCRYPTION (KMS)
resource "aws_s3_bucket_server_side_encryption_configuration" "log_encryption" {
  bucket = aws_s3_bucket.log_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# ✅ LOG BUCKET PUBLIC BLOCK
resource "aws_s3_bucket_public_access_block" "log_block" {
  bucket = aws_s3_bucket.log_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -----------------------------
# 📊 ACCESS LOGGING
# -----------------------------
resource "aws_s3_bucket_logging" "logging" {
  bucket        = aws_s3_bucket.secure_bucket.id
  target_bucket = aws_s3_bucket.log_bucket.id
  target_prefix = "logs/"
}

# -----------------------------
# 🔄 LIFECYCLE (MAIN BUCKET)
# -----------------------------
resource "aws_s3_bucket_lifecycle_configuration" "lifecycle" {
  bucket = aws_s3_bucket.secure_bucket.id

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
# 🔄 LIFECYCLE (LOG BUCKET)
# -----------------------------
resource "aws_s3_bucket_lifecycle_configuration" "log_lifecycle" {
  bucket = aws_s3_bucket.log_bucket.id

  rule {
    id     = "log-cleanup"
    status = "Enabled"

    expiration {
      days = 180
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}