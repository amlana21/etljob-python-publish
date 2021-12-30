import json

import boto3
import os

client = boto3.client('dynamodb')



# import requests


def lambda_handler(event, context):
    response = client.scan(
        TableName=os.getenv('DBNAME'),
        Select='COUNT'
    )

    count = response['Count']

    return {
        "status": "success",
        "totalCount": count
    }
