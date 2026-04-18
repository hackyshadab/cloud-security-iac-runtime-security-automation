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
# ✅ KMS KEY (FIXED)
# -----------------------------
resource "aws_kms_key" "s3_key" {
  description             = "KMS key for S3 encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "Enable IAM User Permissions"
        Effect   = "Allow"
        Principal = {
          AWS = "*"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })
}

# -----------------------------
# ✅ ENCRYPTION
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
# ✅ PUBLIC ACCESS BLOCK
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

# ✅ Log bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "log_encryption" {
  bucket = aws_s3_bucket.log_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ✅ Log bucket versioning
resource "aws_s3_bucket_versioning" "log_versioning" {
  bucket = aws_s3_bucket.log_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# ✅ Log bucket public block
resource "aws_s3_bucket_public_access_block" "log_block" {
  bucket = aws_s3_bucket.log_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -----------------------------
# ✅ ACCESS LOGGING
# -----------------------------
resource "aws_s3_bucket_logging" "logging" {
  bucket        = aws_s3_bucket.secure_bucket.id
  target_bucket = aws_s3_bucket.log_bucket.id
  target_prefix = "logs/"
}

# -----------------------------
# ✅ LIFECYCLE (IMPROVED)
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
# ✅ LOG BUCKET LIFECYCLE
# -----------------------------
resource "aws_s3_bucket_lifecycle_configuration" "log_lifecycle" {
  bucket = aws_s3_bucket.log_bucket.id

  rule {
    id     = "log-cleanup"
    status = "Enabled"

    expiration {
      days = 180
    }
  }
}