import json

import boto3
import os
import datetime
import ast

dbclient = boto3.client('dynamodb')
sqsclient = boto3.client('sqs')



# import requests


def lambda_handler(event, context):
    total_input_count=event['filedatacount']
    # existing_dyna_total=event['totalCount']
    existing_dyna_total=event['l2fresult']['Payload']['totalCount']
    errCount=0

    curr_date_time=datetime.datetime.now()
    curr_date=f'{curr_date_time.year}-{curr_date_time.month}-{curr_date_time.day}'
    # prepare sqs input body
    sqsInpt=json.dumps({"date":f'{curr_date}',"errcount":f'{errCount+total_input_count}',"errtype":"preload"})


    response = sqsclient.send_message(
        QueueUrl=os.getenv('ERRQUEUEURL'),
        MessageBody=sqsInpt,
        DelaySeconds=0,
    )




    return {
        "status": "file_s3_load_error_initial_load"
    }

