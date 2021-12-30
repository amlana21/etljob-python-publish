import sys
from awsglue.utils import getResolvedOptions
from awsglue.context import GlueContext
from awsglue.dynamicframe import DynamicFrame
from awsglue.job import Job
from pyspark import SparkContext

args = getResolvedOptions(sys.argv, ['JOB_NAME', 's3_file_path', 'dynamodb_table'])
sc = SparkContext()
glue_ctx = GlueContext(sc)
spark = glue_ctx.spark_session
job = Job(glue_ctx)
job.init(args['JOB_NAME'], args)

s3_file_path = args['s3_file_path']
dynamodb_table = args['dynamodb_table']

df_src = spark.read.format("csv").option("header", "true").load(s3_file_path)

dyf_result = DynamicFrame.fromDF(df_src, glue_ctx, "dyf_result")

glue_ctx.write_dynamic_frame_from_options(frame=dyf_result, connection_type="dynamodb",connection_options={"dynamodb.output.tableName": dynamodb_table, "dynamodb.throughput.write.percent": "1.0"})

job.commit()