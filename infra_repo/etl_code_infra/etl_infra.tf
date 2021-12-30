terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }

  backend "s3" {
    bucket = "<state_file_name>"
    key    = "etlinfrastate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = "us-east-1"
}


module "s3-bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "2.6.0"
  for_each = toset( var.s3_bukets )
  bucket= each.key

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
  force_destroy = true
}

# ---------------------------sample data file in s3
resource "aws_s3_bucket_object" "data_file" {
  key        = "sample_data.csv"
  bucket     = module.s3-bucket[var.s3_bukets[1]].s3_bucket_id
	source     = "${path.module}/sample_data.csv"
	etag       = filemd5("${path.module}/sample_data.csv")
}

# ---------------------------------for github to s3 lambda function
data "aws_iam_policy_document" "lambda-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "CustLambdaAccess" {
  statement {
    actions   = ["logs:*","s3:*","dynamodb:*","cloudwatch:*","sns:*","lambda:*"]
    effect   = "Allow"
    resources = ["*"]
  }
}

resource "aws_iam_role" "GitToS3Role" {
    name               = "GitToS3Role"
    assume_role_policy = data.aws_iam_policy_document.lambda-assume-role-policy.json
    inline_policy {
        name   = "policy-8675309"
        policy = data.aws_iam_policy_document.CustLambdaAccess.json
    }

}

# ---------------------------------end for github to s3 lambda function

#-------------------main dynamodb table for final record load
module "dynamodb_table" {
  source   = "terraform-aws-modules/dynamodb-table/aws"
  version = "1.1.0"

  for_each = toset( var.dyna_tables )

  name     = each.key
  hash_key = "date"

  billing_mode = "PROVISIONED"

  read_capacity = 10
  write_capacity = 10

  attributes = [
    {
      name = "date"
      type = "S"
    }
  ]

  tags = {
    Terraform   = "true"
  }
}

#-------------------end main dynamodb table for final record load

# ---------------------------sqs queue for errors--------------

module "sqs" {
  source  = "terraform-aws-modules/sqs/aws"
  version = "~> 2.0"

  name = "etlerrors"

  tags = {
    Terraform   = "true"
  }
}


# ---------------------------end sqs queue for errors--------------