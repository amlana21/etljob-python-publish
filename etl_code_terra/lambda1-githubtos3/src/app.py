import requests
import boto3
from datetime import date
import os
import pandas as pd
client=boto3.client(
    's3',
    region_name = 'us-east-1'
)
from dataprocessing.dataprocessing import processData
from loadstatustracking.statuctrackers import dynaDbRecCount,TestDynaDBcount


def lambda_handler(event, context):
    try:
        # output_filename = str(date.today())
        output_filename = os.environ['OUTFILENAME']
        download_urls = [os.environ['GIT_FILE_SRC'],os.environ['GIT_FILE_SRC_TWO']]
        filenames = []
        for idx, filesrc in enumerate(download_urls):
            flename = download_file(filesrc, idx)
            filenames.append(flename)
        print(filenames)
        df1 = pd.read_csv(f"/tmp/{filenames[0]}")
        df2 = pd.read_csv(f"/tmp/{filenames[1]}")
        # print(df1.head())
        # print(df2.head())
        print('before process data')
        output_df = processData(df1, df2)
        filedatacount=len(output_df.index.tolist())
        output_df.to_csv(f"/tmp/{output_filename}.csv")
        target_csv_path = f"/tmp/{output_filename}.csv"
        for fle in filenames:
            os.remove(f"/tmp/{fle}")
        client.upload_file(target_csv_path, os.environ['GIT_FILE_BUCKET'], f"{output_filename}.csv")

        # ---------count dynadb records
        # print(dynaDbRecCount(os.environ['ETLLOADTABLE']))

        #----------------this will be used during testing to count dynadb
        print('This is counting Dynadb')
        # print(TestDynaDBcount(os.environ['ETLLOADTABLE']))
        initialDynaCount=TestDynaDBcount(os.environ['ETLLOADTABLE'])
        if initialDynaCount==0:
            pass
        else:
            pass

        # return 'load_success'
        return {
        "l1status": "load_success",
        "filedatacount":filedatacount
    }
    except Exception as e:
        print(e)
        # return 'load_error'
        return {
        "l1status": "load_error",
        "filedatacount":0
    }



def download_file(fileurl,filename):
    output_filename = str(date.today())
    csv_file_name = f"{output_filename}_{filename}.csv"
    target_csv_path = f"/tmp/{output_filename}_{filename}.csv"
    response = requests.get(fileurl)
    response.raise_for_status()  # Check that the request was successful
    with open(target_csv_path, "wb") as f:
        f.write(response.content)
    return csv_file_name
