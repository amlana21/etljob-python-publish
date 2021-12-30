import boto3
from boto3.dynamodb.conditions import Key, Attr

def dynaDbRecCount(tablename):
    dynamoDBResource = boto3.resource('dynamodb')
    table = dynamoDBResource.Table(tablename)
    print(table.item_count)
    return table.item_count

def TestDynaDBcount(tablename):
    dynamoDBResource = boto3.resource('dynamodb')
    table = dynamoDBResource.Table(tablename)
    response = table.scan(
    FilterExpression=Attr('date').exists()
    )
    items = response['Items']
    return len(items)
