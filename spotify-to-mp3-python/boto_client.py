import boto3
import logging
import os
from botocore.exceptions import NoCredentialsError, PartialCredentialsError, ClientError


session = boto3.Session(
    aws_access_key_id=os.environ['aws_access_key_id'],         # Leave as None to use the environment variable
    aws_secret_access_key=os.environ['aws_secret_access_key'],     # Leave as None to use the environment variable
)

s3 = session.resource('s3')
client = session.client('s3')
bucketCreated = False
bucketName = "cc-spotify"

# for bucket in s3.buckets.all():
#     if bucket.name == "cc-spotify":
#         bucketCreated = True
# if not bucketCreated:
#     s3.create_bucket(Bucket='cc-spotify')


def obj_exists(prefix, ext):
    res = client.list_objects_v2(Bucket=bucketName, Prefix=f'{prefix}.{ext}', MaxKeys=1)
    return 'Contents' in res


def put_obj_s3(data, prefix, ext):
    s3.Bucket(bucketName).put_object(Key=f'{prefix}.{ext}', Body=data)


def create_presigned_url(bucket_name, object_name, expiration=3600):
    # Generate a presigned URL for the S3 object
    try:
        response = client.generate_presigned_url('get_object', Params={'Bucket': bucketName, 'Key': object_name}, ExpiresIn=expiration)
    except ClientError as e:
        print(e)
        logging.error(e)
        return None

    # The response contains the presigned URL
    return response
