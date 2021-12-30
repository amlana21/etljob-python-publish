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
    existing_dyna_total = event['l2result']['Payload']['totalCount']
    errCount=0

    curr_date_time=datetime.datetime.now()
    curr_date=f'{curr_date_time.year}-{curr_date_time.month}-{curr_date_time.day}'
    # print(curr_date)

    response = sqsclient.receive_message(
        QueueUrl=os.getenv('ERRQUEUEURL'),
        AttributeNames=['All'],
        MaxNumberOfMessages=10
    )

    # print(response)
    sqsresp=[]
    # print(response.keys())
    if 'Messages' in response.keys():
        sqsresp=response['Messages']
    if len(sqsresp)!=0:
        sqsbody=sqsresp[0]['Body']
        sqs_dict = ast.literal_eval(sqsbody)
        errCount=int(sqs_dict['errcount'])
        receiptHandle=sqsresp[0]['ReceiptHandle']
        delresponse = sqsclient.delete_message(
            QueueUrl=os.getenv('ERRQUEUEURL'),
            ReceiptHandle=receiptHandle
        )

    # print(errCount)

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
                'N': f'{errCount+1}',
            },
        },
        ReturnConsumedCapacity='TOTAL',
        TableName=os.getenv('DBNAME'),
    )


    return {
        "status": "success"
    }

