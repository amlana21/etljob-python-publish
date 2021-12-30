import json

import boto3
import os
import datetime
import ast

trackingdbclient = boto3.client('dynamodb')
datadbclient=boto3.client('dynamodb')
sqsclient = boto3.client('sqs')



# import requests


def lambda_handler(event, context):
    jobstatus=event['status']
    rowsFailed=event['rows_failed']
    rowsUpdated=event['rows_updated']

    curr_date_time = datetime.datetime.now()
    curr_date = f'{curr_date_time.year}-{curr_date_time.month}-{curr_date_time.day}'

    if jobstatus=='error_post_glue_job':

        # add error row to sqs
        sqsInpt = json.dumps({"date": f'{curr_date}', "errcount": f'{rowsFailed}', "errtype": "postload"})

        sqsresponse = sqsclient.send_message(
            QueueUrl=os.getenv('ERRQUEUEURL'),
            MessageBody=sqsInpt,
            DelaySeconds=0
        )

        #     print(sqsresponse)

        # delete tracking dyna db row
        trackingdelresponse = trackingdbclient.delete_item(
            TableName=os.getenv('TRACKINGDBNAME'),
            Key={
                'date': {
                    'S': curr_date
                }
            }
        )

        return {
            "status": jobstatus,
            "rows_failed": rowsFailed,
            "rows_updated": rowsUpdated
        }


    elif jobstatus=='success_post_glue_job':
        # delete tracking dyna db row
        trackingdelresponse = trackingdbclient.delete_item(
            TableName=os.getenv('TRACKINGDBNAME'),
            Key={
                'date': {
                    'S': curr_date
                }
            }
        )
        return {
            "status": jobstatus,
            "rows_updated": rowsUpdated
        }
    else:
        return {
            "status": "post_glue_job_count_failed"
        }




