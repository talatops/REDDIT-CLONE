terraform {
  backend "s3" {
    bucket         = "newbucke1"
    key            = "EKS/terraform.tfstate"
    region         = "ap-south-1"
   #dynamodb_table = "terraform-lock-table"
    encrypt        = true
    #profile        = "my-aws-profile"
    #role_arn       = "arn:aws:s3:::newbucke1"
    #kms_key_id     = "arn:aws:kms:us-west-2:123456789012:key/your-kms-key-id"
  }
}

