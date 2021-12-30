# provider "aws" {
#   region = "us-east-1"
#   profile = "terralab"
# }


module "lambda-s3-bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "2.6.0"
  bucket= var.lambda10_bucket

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
  force_destroy = true
}

resource "aws_s3_bucket_object" "lambda10_code" {
  key        = "lambda-builds/lambda10-postglue-success_verify.zip"
  bucket     = module.lambda-s3-bucket.s3_bucket_id
  source     = "${path.module}/src/lambda10-postglue-success_verify.zip"
  etag       = filemd5("${path.module}/src/lambda10-postglue-success_verify.zip")
}

module "lambda_function_local" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = "lambda10-postglue-success_verify"
  description   = "Lambda for Lambda10"
  handler       = "app.lambda_handler"
  runtime       = "python3.8"
  publish       = true
  store_on_s3 = true
  s3_bucket   = module.lambda-s3-bucket.s3_bucket_id
  # s3_prefix   = "lambda-builds/"

  create_package         = false
   s3_existing_package = {
     bucket = module.lambda-s3-bucket.s3_bucket_id
     key = "lambda-builds/lambda10-postglue-success_verify.zip"
     version_id = null
   }

  environment_variables = {
    ERRQUEUEURL      = var.sqs_err_queue
    DATADBNAME      = var.data_dyna_table
    TRACKINGDBNAME      = var.tracking_dyna_table
  }
  lambda_role   = var.lambda_role
  timeout = 15
  create_role = false

  depends_on = [resource.aws_s3_bucket_object.lambda10_code]

}
