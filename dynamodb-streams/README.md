# dynamodb-streams

Terraform for an `orders` DynamoDB table with a stream, a Java 21 Lambda consumer, and an event source mapping with retry, batch splitting and an SQS failure destination.

## Goal
Show how to consume a DynamoDB stream safely: partial batch responses, bounded retries and a place for records that keep failing.

## Run it
```
terraform init -backend=false
terraform validate
```
Expected: Terraform reports the configuration as valid. This was not run in this pass, so no output is quoted.

To apply, start LocalStack, build a shaded jar containing `com.example.orders.StreamHandler` and set `jar_path` (default `build/stream-consumer.jar`), then `terraform apply` and later `terraform destroy`. For real AWS add `-var use_localstack=false`; the table is pay-per-request.

Not run end to end: the handler code is not in this repo, so no stream record was processed.

## What it proves
- The table streams `NEW_AND_OLD_IMAGES`, so the consumer sees both versions of a changed item.
- The mapping uses `ReportBatchItemFailures`, `bisect_batch_on_function_error` and `maximum_retry_attempts = 3`, so one bad record does not block a whole batch indefinitely.
- After retries, failure details go to the `orders-stream-failures` queue; the role may call `sqs:SendMessage` on it.

## Trade-offs
- The jar is built outside this folder, and the handler class must match the configured name.
- The failure destination holds record metadata, not the record itself; the data must be fetched from the stream before it expires.
- `starting_position = "LATEST"` skips records written before the mapping exists.

## When not to use it
- When consumers need to replay long history; use Kinesis Data Streams or an export.
- For simple cross-service fan-out, where EventBridge Pipes needs no code.
