# provider "aws" {
#   region = "us-east-1"
#   profile = "terralab"
# }


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
    actions   = ["logs:*","s3:*","dynamodb:*","cloudwatch:*","sns:*","lambda:*","connect:*","secretsmanager:*","ds:*","sqs:*"]
    effect   = "Allow"
    resources = ["*"]
  }
}

resource "aws_iam_role" "lambda2RoleCust" {
    name               = "lambda2RoleCust"
    assume_role_policy = data.aws_iam_policy_document.lambda-assume-role-policy.json
    inline_policy {
        name   = "policy-8675310"
        policy = data.aws_iam_policy_document.CustLambdaAccess.json
    }

}

module "lambda-s3-bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "2.6.0"
  bucket= var.lambda2_bucket

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
  force_destroy = true
}

resource "aws_s3_bucket_object" "lambda_code" {
  key        = "lambda-builds/lambda2_countdyna.zip"
  bucket     = module.lambda-s3-bucket.s3_bucket_id
  source     = "${path.module}/src/lambda2_countdyna.zip"
  etag       = filemd5("${path.module}/src/lambda2_countdyna.zip")
}

module "lambda_function_local" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = "lambda2_countdyna"
  description   = "Lambda for countdyna"
  handler       = "app.lambda_handler"
  runtime       = "python3.8"
  publish       = true
  store_on_s3 = true
  s3_bucket   = module.lambda-s3-bucket.s3_bucket_id

  create_package         = false
   s3_existing_package = {
     bucket = module.lambda-s3-bucket.s3_bucket_id
     key = "lambda-builds/lambda2_countdyna.zip"
     version_id = null
   }

  environment_variables = {
    DBNAME      = var.dyna_table
  }
  lambda_role   = var.lambda_role
  timeout = 15
  create_role = false

  depends_on = [resource.aws_s3_bucket_object.lambda_code]

}
