import json

import boto3
import os
import datetime
import ast

snsclient=boto3.client('sns')



# import requests


def lambda_handler(event, context):
    print(event)

    jobStatus=event['status']
    if jobStatus=='error_post_glue_job':
        rowsFailed = event['rows_failed']
        rowsUpdated = event['rows_updated']

        response = snsclient.publish(
            TopicArn=os.getenv('SNSTOPIC'),
            Message=f'Job Status: {jobStatus} || Total Rows Failed: {rowsFailed} || Total Rows Created/Updated: {rowsUpdated}',
            Subject='Glue Job Run Stats'
        )
    elif jobStatus=='success_post_glue_job':
        rowsUpdated = event['rows_updated']

        response = snsclient.publish(
            TopicArn=os.getenv('SNSTOPIC'),
            Message=f'Job Status: {jobStatus} || Total Rows Created/Updated: {rowsUpdated}',
            Subject='Glue Job Run Stats'
        )
    elif jobStatus=='file_s3_load_error' or jobStatus=='file_s3_load_error_initial_load':
        # rowsUpdated = event['rows_updated']

        response = snsclient.publish(
            TopicArn=os.getenv('SNSTOPIC'),
            Message=f'Job Status: {jobStatus} || The job failed at the first step of loading data from source to S3',
            Subject='Glue Job Run Stats'
        )
    elif jobStatus=='abrupt_lambda_failure':
        # rowsUpdated = event['rows_updated']

        response = snsclient.publish(
            TopicArn=os.getenv('SNSTOPIC'),
            Message=f'Job Status: {jobStatus} || Message: {event["message"]} || The job failed due to a Lambda error. Probably a cleanup will be needed on error table.',
            Subject='Glue Job Run Stats'
        )







    




    return {
        "status": "done"
    }



    