# s3-event-pipeline

Terraform for an S3 bucket that sends an event to an SQS queue whenever a CSV file lands under `incoming/`.

## Goal
Show the S3 to SQS notification wiring, including the queue policy that lets S3 send messages and the filters that limit what triggers it.

## Run it
```
terraform init -backend=false
terraform validate
```
Expected: Terraform reports the configuration as valid. This was not run in this pass, so no output is quoted.

To apply, start LocalStack and run `terraform apply`, then upload `incoming/orders.csv` to bucket `orders-inbox-lab` and read the `orders-uploads` queue. Finish with `terraform destroy`. For real AWS add `-var use_localstack=false`; the bucket name must be globally unique, so change it first.

Not run end to end: no upload or message receipt was tried.

## What it proves
- The notification fires on `s3:ObjectCreated:*` with prefix `incoming/` and suffix `.csv`, so other keys do nothing.
- `aws_sqs_queue_policy.uploads` allows only `s3.amazonaws.com`, and only when `aws:SourceArn` is this bucket.
- The notification `depends_on` the queue policy, which avoids a validation error at create time.
- The bucket blocks all public access, and `force_destroy` lets it be deleted while holding objects.

## Trade-offs
- The queue has no consumer or dead-letter queue.
- `force_destroy = true` is for the lab and would delete data in real use.
- The bucket name is hard-coded.

## When not to use it
- When you need several targets or filtering on object metadata; use EventBridge notifications.
- When the work is a single Lambda, which S3 can invoke directly.
