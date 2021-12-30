terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }

  backend "s3" {
    bucket = "<state_file_name>"
    key    = "etlcodesstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_sqs_queue" "etlerrorqueue" {
  name = "etlerrors"
}


module "lambda1_githubtos3" {
    source = "./lambda1-githubtos3"

    lambda_role = module.security_components.lambda_role

    depends_on = [module.security_components]
}

module "lambda2_countdyna" {
    source = "./lambda2-countdyna"

    lambda_role = module.security_components.lambda_role

    depends_on = [module.security_components]
}

module "lambda3-preglue-deltajoba" {
    source = "./lambda3-preglue-deltajob"

    lambda_role = module.security_components.lambda_role
    sqs_err_queue = data.aws_sqs_queue.etlerrorqueue.url

    depends_on = [module.security_components]
}

module "lambda6-loadsuccess-preglue-initialjob" {
    source = "./lambda6-loadsuccess-preglue-initialjob"

    lambda_role = module.security_components.lambda_role

    depends_on = [module.security_components]
}

module "lambda5-loaderr-deltajob" {
    source = "./lambda5-loaderr-deltajob"

    lambda_role = module.security_components.lambda_role
    sqs_err_queue = data.aws_sqs_queue.etlerrorqueue.url

    depends_on = [module.security_components]
}

module "lambda7-loaderr-initjob" {
  source = "./lambda7-loaderr-initjob"

  lambda_role = module.security_components.lambda_role
  sqs_err_queue = data.aws_sqs_queue.etlerrorqueue.url

  depends_on = [module.security_components]
}

module "lambda8-postglue-identifystatus" {
  source = "./lambda8-postglue-identifystatus"

  lambda_role = module.security_components.lambda_role

  depends_on = [module.security_components]
}

module "lambda9-postglue-errprocess" {
  source = "./lambda9-postglue-errprocess"

  lambda_role = module.security_components.lambda_role
  sqs_err_queue = data.aws_sqs_queue.etlerrorqueue.url

  depends_on = [module.security_components]
}

module "lambda10-postglue-success_verify" {
  source = "./lambda10-postglue-success_verify"

  lambda_role = module.security_components.lambda_role
  sqs_err_queue = data.aws_sqs_queue.etlerrorqueue.url

  depends_on = [module.security_components]
}

module "lambda11-postglue-afterverify" {
  source = "./lambda11-postglue-afterverify"

  lambda_role = module.security_components.lambda_role
  sqs_err_queue = data.aws_sqs_queue.etlerrorqueue.url

  depends_on = [module.security_components]
}


module "lambda12-sns_notifications" {
  source = "./lambda12-sns_notifications"

  lambda_role = module.security_components.lambda_role
  sns_topic_name = "etl_notifications_topic"

  depends_on = [module.security_components]
}

module "security_components" {
    source = "./security-module"
}