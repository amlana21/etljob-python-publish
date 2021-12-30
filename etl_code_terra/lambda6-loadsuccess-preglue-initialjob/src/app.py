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
    existing_dyna_total = event['l2result']['Payload']['totalCount']
    errCount=0

    curr_date_time=datetime.datetime.now()
    curr_date=f'{curr_date_time.year}-{curr_date_time.month}-{curr_date_time.day}'

    dbresponse = dbclient.put_item(
        Item={
            'date': {
                'S': curr_date,
            },
            'total_input_count': {
                'N': f'{total_input_count}',
            },
            'preload_db_count': {
                'N': f'{existing_dyna_total}',
            },
            'delta_to_load': {
                'N': f'{total_input_count}',
            },
        },
        ReturnConsumedCapacity='TOTAL',
        TableName=os.getenv('DBNAME'),
    )


    return {
        "status": "success"
    }