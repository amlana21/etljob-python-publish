import json

import boto3
import os
import datetime
import ast




def lambda_handler(event, context):
    jobstatus='error_post_glue_job'
    reasonStr=''

    if 'Error' in event.keys():
        reasonStr=event['Cause']['ErrorMessage']
    elif 'JobRunState' in event.keys():
        jobstatus='success_glue_job'
    return {
        "status": jobstatus,
        "reason":reasonStr
    }

