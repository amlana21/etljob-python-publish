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
    # getting the data count from data db after load
    response = datadbclient.scan(
        TableName=os.getenv('DATADBNAME'),
        Select='COUNT'
    )

    postLoadcount = response['Count']

    print(postLoadcount)

    # getting the tracking date from tracking db
    curr_date_time = datetime.datetime.now()
    curr_date = f'{curr_date_time.year}-{curr_date_time.month}-{curr_date_time.day}'
    trackingresponse = trackingdbclient.get_item(
        TableName=os.getenv('TRACKINGDBNAME'),
        Key={
            'date': {
                'S': curr_date
            }
        }
    )

    print(trackingresponse)

    preload_count=int(trackingresponse['Item']['preload_db_count']['S'])
    to_be_loaded_count=int(trackingresponse['Item']['delta_to_load']['S'])
    rows_failed=0
    rows_updated=0

    # if int(postLoadcount)!=(preload_count+to_be_loaded_count):
    rows_failed=abs(postLoadcount-(preload_count+to_be_loaded_count))
    rows_updated=postLoadcount-preload_count

    # delete tracking dyna db row
    trackingdelresponse = trackingdbclient.delete_item(
        TableName=os.getenv('TRACKINGDBNAME'),
        Key={
            'date': {
                'S': curr_date
            }
        }
    )


    # add error row to sqs
    
    sqsInpt = json.dumps({"date": f'{curr_date}', "errcount": f'{rows_failed}', "errtype": "postload"})

    sqsresponse = sqsclient.send_message(
        QueueUrl=os.getenv('ERRQUEUEURL'),
        MessageBody=sqsInpt,
        DelaySeconds=0
    )

    print(sqsresponse)




    return {
        "status": "error_post_glue_job",
        "rows_failed":rows_failed,
        "rows_updated":rows_updated
    }



