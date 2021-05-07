provider "aws" {
  region = "us-west-1"
}
resource "aws_s3_bucket" "bucketname" {
  bucket = "terraform-bucketname"
  acl = "private"

  lifecycle_rule {
    enabled = true

    transition {
      days = 60
      storage_class = "STANDARD_IA"
    }

    transition {
      days = 90
      storage_class = "GLACIER"
    }
  }
}