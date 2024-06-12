terraform {
  backend "s3" {
    bucket         = "redditt"
    key            = "EKS/terraform.tfstate"
    region         = "ap-south-1"
   #dynamodb_table = "terraform-lock-table"
    encrypt        = true
    #profile        = "my-aws-profile"
    #role_arn       = "arn:aws:s3:::redditt"
    #kms_key_id     = "arn:aws:kms:us-west-2:123456789012:key/your-kms-key-id"
  }
}

