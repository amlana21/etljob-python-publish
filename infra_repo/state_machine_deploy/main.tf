terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }

  backend "s3" {
    bucket = "<state_file_name>"
    key    = "statemachineinfrastate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = "us-east-1"
}


data "aws_iam_policy_document" "state-machine-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "CuststateMachineAccess" {
  statement {
    actions   = ["logs:*","s3:*","dynamodb:*","cloudwatch:*","sns:*","lambda:*","connect:*","secretsmanager:*","ds:*","sqs:*","glue:*","xray:*"]
    effect   = "Allow"
    resources = ["*"]
  }
}

resource "aws_iam_role" "stateMachineRoleCust" {
    name               = "stateMachineRoleCust"
    assume_role_policy = data.aws_iam_policy_document.state-machine-assume-role-policy.json
    inline_policy {
        name   = "policy-867531221"
        policy = data.aws_iam_policy_document.CuststateMachineAccess.json
    }

}


resource "aws_sfn_state_machine" "etl_state_machine" {
  name     = "etl_state_machine"
  role_arn = resource.aws_iam_role.stateMachineRoleCust.arn

  definition = <<EOF
{
  "Comment": "A description of my state machine",
  "StartAt": "Load from Github",
  "States": {
    "Load from Github": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "OutputPath": "$.Payload",
      "Parameters": {
        "Payload.$": "$",
        "FunctionName": "arn:aws:lambda:us-east-1:${var.aws_acct_num}:function:lambda1-githubtos3:$LATEST"
      },
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException"
          ],
          "IntervalSeconds": 2,
          "MaxAttempts": 6,
          "BackoffRate": 2
        }
      ],
      "Next": "Check Load Status"
    },
    "Check Load Status": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.l1status",
          "StringEquals": "load_success",
          "Next": "Success: Run L2"
        }
      ],
      "Default": "Failed: Run L2"
    },
    "Failed: Run L2": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "Payload.$": "$",
        "FunctionName": "arn:aws:lambda:us-east-1:${var.aws_acct_num}:function:lambda2_countdyna:$LATEST"
      },
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException"
          ],
          "IntervalSeconds": 2,
          "MaxAttempts": 6,
          "BackoffRate": 2
        }
      ],
      "ResultPath": "$.l2fresult",
      "Next": "L1 Failed: Count Dyna"
    },
    "L1 Failed: Count Dyna": {
      "Type": "Choice",
      "Choices": [
        {
          "And": [
            {
              "Variable": "$.l2fresult.Payload.status",
              "StringEquals": "success"
            },
            {
              "Variable": "$.l2fresult.Payload.totalCount",
              "NumericGreaterThan": 0
            }
          ],
          "Next": ">0: Run L5",
          "Comment": ">0"
        },
        {
          "And": [
            {
              "Variable": "$.l2fresult.Payload.status",
              "StringEquals": "success"
            },
            {
              "Variable": "$.l2fresult.Payload.totalCount",
              "NumericEquals": 0
            }
          ],
          "Next": "=0: Run L7"
        }
      ],
      "Default": "Send SNS Status: L1 Failed"
    },
    ">0: Run L5": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "OutputPath": "$.Payload",
      "Parameters": {
        "Payload.$": "$",
        "FunctionName": "arn:aws:lambda:us-east-1:${var.aws_acct_num}:function:lambda5-loaderr-deltajob:$LATEST"
      },
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException"
          ],
          "IntervalSeconds": 2,
          "MaxAttempts": 6,
          "BackoffRate": 2
        }
      ],
      "Next": "Send SNS Status: L1 Failed"
    },
    "Send SNS Status: L1 Failed": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "OutputPath": "$.Payload",
      "Parameters": {
        "Payload.$": "$",
        "FunctionName": "arn:aws:lambda:us-east-1:${var.aws_acct_num}:function:lambda12-sns_notifications:$LATEST"
      },
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException"
          ],
          "IntervalSeconds": 2,
          "MaxAttempts": 6,
          "BackoffRate": 2
        }
      ],
      "End": true
    },
    "Success: Run L2": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "Payload.$": "$",
        "FunctionName": "arn:aws:lambda:us-east-1:${var.aws_acct_num}:function:lambda2_countdyna:$LATEST"
      },
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException"
          ],
          "IntervalSeconds": 2,
          "MaxAttempts": 6,
          "BackoffRate": 2
        }
      ],
      "Next": "Count Dyna",
      "ResultPath": "$.l2result"
    },
    "Count Dyna": {
      "Type": "Choice",
      "Choices": [
        {
          "And": [
            {
              "Variable": "$.l2result.Payload.status",
              "StringEquals": "success"
            },
            {
              "Variable": "$.l2result.Payload.totalCount",
              "NumericGreaterThan": 0
            }
          ],
          "Next": ">0: Run L3"
        },
        {
          "And": [
            {
              "Variable": "$.l2result.Payload.status",
              "StringEquals": "success"
            },
            {
              "Variable": "$.l2result.Payload.totalCount",
              "NumericEquals": 0
            }
          ],
          "Next": "= 0: Run L6"
        }
      ],
      "Default": "Send SNS: Count Dyna failed"
    },
    "Send SNS: Count Dyna failed": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "OutputPath": "$.Payload",
      "Parameters": {
        "FunctionName": "arn:aws:lambda:us-east-1:${var.aws_acct_num}:function:lambda12-sns_notifications:$LATEST",
        "Payload": {
          "status": "abrupt_lambda_failure",
          "message": "L2:Count Dyna Failed"
        }
      },
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException"
          ],
          "IntervalSeconds": 2,
          "MaxAttempts": 6,
          "BackoffRate": 2
        }
      ],
      "Next": "Fail"
    },
    ">0: Run L3": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "OutputPath": "$.Payload",
      "Parameters": {
        "Payload.$": "$",
        "FunctionName": "arn:aws:lambda:us-east-1:${var.aws_acct_num}:function:lambda3-preglue-deltajob:$LATEST"
      },
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException"
          ],
          "IntervalSeconds": 2,
          "MaxAttempts": 6,
          "BackoffRate": 2
        }
      ],
      "Next": "L3 Status"
    },
    "L3 Status": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.status",
          "StringEquals": "success",
          "Next": ">0: Glue StartJobRun"
        }
      ],
      "Default": "Send SNS: L3 Failed"
    },
    "Send SNS: L3 Failed": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "OutputPath": "$.Payload",
      "Parameters": {
        "FunctionName": "arn:aws:lambda:us-east-1:${var.aws_acct_num}:function:lambda12-sns_notifications:$LATEST",
        "Payload": {
          "status": "abrupt_lambda_failure",
          "message": "L3 Failed"
        }
      },
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException"
          ],
          "IntervalSeconds": 2,
          "MaxAttempts": 6,
          "BackoffRate": 2
        }
      ],
      "Next": "L3 Failed"
    },
    ">0: Glue StartJobRun": {
      "Type": "Task",
      "Resource": "arn:aws:states:::glue:startJobRun.sync",
      "Parameters": {
        "JobName": "etl_data_job"
      },
      "Next": "Glue Job Status Check"
    },
    "L3 Failed": {
      "Type": "Fail"
    },
    "Fail": {
      "Type": "Fail"
    },
    "= 0: Run L6": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "Parameters": {
        "Payload.$": "$",
        "FunctionName": "arn:aws:lambda:us-east-1:${var.aws_acct_num}:function:lambda6-loadsuccess-preglue-initialjob:$LATEST"
      },
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException"
          ],
          "IntervalSeconds": 2,
          "MaxAttempts": 6,
          "BackoffRate": 2
        }
      ],
      "ResultPath": "$.l6result",
      "Next": "L6 Status"
    },
    "L6 Status": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.l6result.Payload.status",
          "StringEquals": "success",
          "Next": "= 0: Glue StartJobRun"
        }
      ],
      "Default": "Send SNS: L6 Failed"
    },
    "Send SNS: L6 Failed": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "OutputPath": "$.Payload",
      "Parameters": {
        "FunctionName": "arn:aws:lambda:us-east-1:${var.aws_acct_num}:function:lambda12-sns_notifications:$LATEST",
        "Payload": {
          "status": "abrupt_lambda_failure",
          "message": "L6 Failed"
        }
      },
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException"
          ],
          "IntervalSeconds": 2,
          "MaxAttempts": 6,
          "BackoffRate": 2
        }
      ],
      "Next": "L6 Failed"
    },
    "= 0: Glue StartJobRun": {
      "Type": "Task",
      "Resource": "arn:aws:states:::glue:startJobRun.sync",
      "Parameters": {
        "JobName": "etl_data_job"
      },
      "Next": "Glue Job Status Check"
    },
    "Glue Job Status Check": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.JobRunState",
          "StringEquals": "SUCCEEDED",
          "Next": "Run L8: Check Glue Status"
        }
      ],
      "Default": "Run L8: Check Glue Status"
    },
    "Run L8: Check Glue Status": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "OutputPath": "$.Payload",
      "Parameters": {
        "Payload.$": "$",
        "FunctionName": "arn:aws:lambda:us-east-1:${var.aws_acct_num}:function:lambda8-postglue-identifystatus:$LATEST"
      },
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException"
          ],
          "IntervalSeconds": 2,
          "MaxAttempts": 6,
          "BackoffRate": 2
        }
      ],
      "Next": "L8 Status Check"
    },
    "L8 Status Check": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.status",
          "StringEquals": "success_glue_job",
          "Next": "Glue Job Success: Run L10"
        }
      ],
      "Default": "Glue Job Failed: Run L9"
    },
    "Glue Job Failed: Run L9": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "OutputPath": "$.Payload",
      "Parameters": {
        "Payload.$": "$",
        "FunctionName": "arn:aws:lambda:us-east-1:${var.aws_acct_num}:function:lambda9-postglue-errprocess:$LATEST"
      },
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException"
          ],
          "IntervalSeconds": 2,
          "MaxAttempts": 6,
          "BackoffRate": 2
        }
      ],
      "Next": "Send SNS Status: Glue Job Failed"
    },
    "Send SNS Status: Glue Job Failed": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "OutputPath": "$.Payload",
      "Parameters": {
        "Payload.$": "$",
        "FunctionName": "arn:aws:lambda:us-east-1:${var.aws_acct_num}:function:lambda12-sns_notifications:$LATEST"
      },
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException"
          ],
          "IntervalSeconds": 2,
          "MaxAttempts": 6,
          "BackoffRate": 2
        }
      ],
      "Next": "Glue Job Fail Path"
    },
    "Glue Job Success: Run L10": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "OutputPath": "$.Payload",
      "Parameters": {
        "Payload.$": "$",
        "FunctionName": "arn:aws:lambda:us-east-1:${var.aws_acct_num}:function:lambda10-postglue-success_verify:$LATEST"
      },
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException"
          ],
          "IntervalSeconds": 2,
          "MaxAttempts": 6,
          "BackoffRate": 2
        }
      ],
      "Next": "Check L10 Status"
    },
    "Check L10 Status": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.status",
          "StringEquals": "success_post_glue_job",
          "Next": "Glue Job Success: Run L11"
        },
        {
          "Variable": "$.status",
          "StringEquals": "error_post_glue_job",
          "Next": "Glue Job Failed: Run L11"
        }
      ],
      "Default": "Send SNS Status"
    },
    "Glue Job Success: Run L11": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "OutputPath": "$.Payload",
      "Parameters": {
        "Payload.$": "$",
        "FunctionName": "arn:aws:lambda:us-east-1:${var.aws_acct_num}:function:lambda11-postglue-afterverify:$LATEST"
      },
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException"
          ],
          "IntervalSeconds": 2,
          "MaxAttempts": 6,
          "BackoffRate": 2
        }
      ],
      "Next": "Send SNS Status"
    },
    "Glue Job Fail Path": {
      "Type": "Fail"
    },
    "L6 Failed": {
      "Type": "Fail"
    },
    "=0: Run L7": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "OutputPath": "$.Payload",
      "Parameters": {
        "Payload.$": "$",
        "FunctionName": "arn:aws:lambda:us-east-1:${var.aws_acct_num}:function:lambda7-loaderr-initjob:$LATEST"
      },
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException"
          ],
          "IntervalSeconds": 2,
          "MaxAttempts": 6,
          "BackoffRate": 2
        }
      ],
      "Next": "Send SNS Status: L1 Failed"
    },
    "Glue Job Failed: Run L11": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "OutputPath": "$.Payload",
      "Parameters": {
        "Payload.$": "$",
        "FunctionName": "arn:aws:lambda:us-east-1:${var.aws_acct_num}:function:lambda11-postglue-afterverify:$LATEST"
      },
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException"
          ],
          "IntervalSeconds": 2,
          "MaxAttempts": 6,
          "BackoffRate": 2
        }
      ],
      "Next": "Send SNS Status"
    },
    "Send SNS Status": {
      "Type": "Task",
      "Resource": "arn:aws:states:::lambda:invoke",
      "OutputPath": "$.Payload",
      "Parameters": {
        "Payload.$": "$",
        "FunctionName": "arn:aws:lambda:us-east-1:${var.aws_acct_num}:function:lambda12-sns_notifications:$LATEST"
      },
      "Retry": [
        {
          "ErrorEquals": [
            "Lambda.ServiceException",
            "Lambda.AWSLambdaException",
            "Lambda.SdkClientException"
          ],
          "IntervalSeconds": 2,
          "MaxAttempts": 6,
          "BackoffRate": 2
        }
      ],
      "End": true
    }
  }
}
EOF
}