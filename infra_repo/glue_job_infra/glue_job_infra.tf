terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }

  backend "s3" {
    bucket = "<state_file_name>"
    key    = "glueinfrastate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = "us-east-1"
}


# ---------------------------------for glue crawler
data "aws_iam_policy_document" "glue-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["glue.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "CustGlueAccess" {
  statement {
    actions   = ["logs:*","s3:*","dynamodb:*","cloudwatch:*","sns:*","lambda:*","glue:*","ec2:*","iam:*","cloudwatch:PutMetricData"]
    effect   = "Allow"
    resources = ["*"]
  }
}

resource "aws_iam_role" "GlueCrawlerRole" {
    name               = "CustGlueCrawlerRole"
    assume_role_policy = data.aws_iam_policy_document.glue-assume-role-policy.json
    inline_policy {
        name   = "policy-86753091"
        policy = data.aws_iam_policy_document.CustGlueAccess.json
    }

}

# ---------------------------------for glue crawler

resource "aws_glue_catalog_database" "glue_catalog_dest_db" {
  name = "glue_catalog_dest_db"
}

resource "aws_glue_crawler" "glue_crawler_ddb" {
  database_name = aws_glue_catalog_database.glue_catalog_dest_db.name
  name          = "glue_crawler_ddb"
  role          = aws_iam_role.GlueCrawlerRole.arn

  dynamodb_target {
    path = var.glue_dest_dyna_table
  }
}

# ---------------------------------for glue crawler from source S3
resource "aws_glue_catalog_database" "glue_catalog_src_db" {
  name = "glue_catalog_src_db"
}

resource "aws_glue_crawler" "glue_crawler_s3" {
  database_name = aws_glue_catalog_database.glue_catalog_src_db.name
  name          = "glue_crawler_s3"
  role          = aws_iam_role.GlueCrawlerRole.arn

  s3_target {
    path = "s3://${var.glue_job_src_bucket}"
  }
}

# ---------------------------------------------for glue job and glue job itself

module "s3-bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "2.6.0"
  for_each = toset( var.glue_job_buckets )
  bucket= each.key
  # bucket= var.glue_job_script

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
  force_destroy = true
}
resource "aws_s3_bucket_object" "script_file" {
  key        = "glue_script.py"
  bucket     = module.s3-bucket[var.glue_job_buckets[0]].s3_bucket_id
	source     = "${path.module}/glue_script.py"
	etag       = filemd5("${path.module}/glue_script.py")
}

resource "aws_glue_job" "etl_data_job" {
  name     = "etl_data_job"
  role_arn = aws_iam_role.GlueCrawlerRole.arn

  command {
    script_location = "s3://${var.glue_job_buckets[0]}/glue_script.py"
  }

  default_arguments = {
    "--s3_file_path"          = "s3://${var.glue_job_src_bucket}/${var.src_data_file}"
    "--dynamodb_table" = var.dest_db_name
    "--TempDir" = "s3://${var.glue_job_buckets[1]}"
  }

  glue_version = "2.0"
  worker_type = "G.1X"
  number_of_workers = "2"

  depends_on=[module.s3-bucket]
}



resource "aws_sns_topic" "etl_notifications_topic" {
  name = "etl_notifications_topic"
}

resource "aws_sns_topic_subscription" "user_updates_sqs_target" {
  topic_arn = resource.aws_sns_topic.etl_notifications_topic.arn
  protocol  = "email"
  endpoint  = "amlana21@gmail.com"
}