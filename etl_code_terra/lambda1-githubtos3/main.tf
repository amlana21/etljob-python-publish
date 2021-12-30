



module "lambda1-s3-bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "2.6.0"
  for_each = toset( var.lambda1_buckets )
  bucket= each.key

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
  force_destroy = true
}

resource "aws_s3_bucket_object" "lambda1_code" {
  key        = "lambda-builds/lambda1-githubtos3.zip"
  bucket     = module.lambda1-s3-bucket[var.lambda1_buckets[0]].s3_bucket_id
  source     = "${path.module}/src/lambda1-githubtos3.zip"
  etag       = filemd5("${path.module}/src/lambda1-githubtos3.zip")
}

resource "aws_s3_bucket_object" "lambda_layer_package" {
  key        = "lambda-layer/package.zip"
  bucket     = module.lambda1-s3-bucket[var.lambda1_buckets[1]].s3_bucket_id
  source     = "${path.module}/src/package.zip"
  etag       = filemd5("${path.module}/src/package.zip")
}

module "lambda_layer_with_package" {
  source = "terraform-aws-modules/lambda/aws"

  create_layer = true
  store_on_s3 = true

  layer_name          = "lambda1-layer"
  description         = "Lambda layer"
  compatible_runtimes = ["python3.8"]

  create_package         = false
  s3_existing_package = {
     bucket = module.lambda1-s3-bucket[var.lambda1_buckets[1]].s3_bucket_id
     key = "lambda-layer/package.zip"
     version_id = null
   }

  ignore_source_code_hash = true

  depends_on = [resource.aws_s3_bucket_object.lambda_layer_package]
}

module "lambda_function_local" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = "lambda1-githubtos3"
  description   = "Lambda for github to s3"
  handler       = "app.lambda_handler"
  runtime       = "python3.8"
  publish       = true
  store_on_s3 = true
  s3_bucket   = module.lambda1-s3-bucket[var.lambda1_buckets[0]].s3_bucket_id

  create_package         = false
   s3_existing_package = {
     bucket = module.lambda1-s3-bucket[var.lambda1_buckets[0]].s3_bucket_id
     key = "lambda-builds/lambda1-githubtos3.zip"
     version_id = null
   }

  environment_variables = {
    GIT_FILE_BUCKET      = var.src_file_bucket
    GIT_FILE_SRC        = var.git_file_src
    GIT_FILE_SRC_TWO    = var.git_file_src_2
    ETLLOADTABLE    = var.etl_load_table
    OUTFILENAME = var.output_file_name
  }
  lambda_role   = var.lambda_role
  timeout = 15
  create_role = false

  layers = [
    module.lambda_layer_with_package.lambda_layer_arn
  ]

  depends_on = [resource.aws_s3_bucket_object.lambda1_code,resource.aws_s3_bucket_object.lambda_layer_package]

}