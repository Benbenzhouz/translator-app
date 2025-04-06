# main.tf
provider "aws" {
  region = "ap-southeast-2"
}

# 生成随机后缀用于唯一 bucket 名字
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# 创建用于前端文件存储的 S3 Bucket
resource "aws_s3_bucket" "frontend_bucket" {
  bucket = "frontend-site-${random_id.bucket_suffix.hex}"

  website {
    index_document = "index.html"
    error_document = "404.html"
  }

  tags = {
    Name = "FrontendHosting"
  }
}

# 设置 S3 Object Ownership（必须，才能不用 ACL）
resource "aws_s3_bucket_ownership_controls" "ownership" {
  bucket = aws_s3_bucket.frontend_bucket.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# 禁用阻止公共访问的策略
resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket                  = aws_s3_bucket.frontend_bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# 设置 Bucket Policy 允许 public 读取文件
resource "aws_s3_bucket_policy" "public_read" {
  bucket = aws_s3_bucket.frontend_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.frontend_bucket.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.public_access]
}

# 上传本地 out 目录中的所有文件
resource "aws_s3_bucket_object" "frontend_files" {
  for_each = fileset("out", "**")

  bucket = aws_s3_bucket.frontend_bucket.id
  key    = each.value
  source = "out/${each.value}"
  etag   = filemd5("out/${each.value}")

  content_type = lookup(
    {
      html = "text/html"
      css  = "text/css"
      js   = "application/javascript"
      json = "application/json"
      png  = "image/png"
      jpg  = "image/jpeg"
      jpeg = "image/jpeg"
      svg  = "image/svg+xml"
      ico  = "image/x-icon"
      txt  = "text/plain"
    },
    regex("[^.]+$", each.value),
    "application/octet-stream"
  )

  depends_on = [
    aws_s3_bucket_policy.public_read
  ]
}

# 输出访问地址
output "website_url" {
  value = aws_s3_bucket.frontend_bucket.website_endpoint
}
