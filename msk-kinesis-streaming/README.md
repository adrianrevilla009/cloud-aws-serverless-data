# msk-kinesis-streaming

Terraform for an on-demand Kinesis stream, `orders-stream`, and an enhanced fan-out consumer named `analytics`.

## Goal
Show a streaming setup that can run on LocalStack and why Kinesis was chosen here instead of MSK.

## Run it
```
terraform init -backend=false
terraform validate
```
Expected: Terraform reports the configuration as valid. This was not run in this pass, so no output is quoted.

To apply, start LocalStack and run `terraform apply`, then `terraform destroy`. For real AWS add `-var use_localstack=false`; on-demand streams and enhanced fan-out are billed per hour and per GB, so destroy promptly.

Not run end to end: nothing was written to or read from the stream.

## What it proves
- `stream_mode = "ON_DEMAND"` removes shard sizing, with 24 hours of retention.
- `aws_kinesis_stream_consumer.analytics` registers an enhanced fan-out consumer, which gets its own read pipe instead of sharing throughput.
- No MSK cluster is declared. A comment in `main.tf` gives the reasons: brokers cost roughly $0.20 or more per hour each, are outside the free tier, and LocalStack supports MSK only in its paid edition.

## Trade-offs
- Kinesis is not Kafka: there are no Kafka client APIs, consumer groups or compaction.
- Enhanced fan-out costs extra per consumer, so use it only when shared read throughput is a problem.
- Retention is a day, so slow consumers can lose data.

## When not to use it
- When you need the Kafka ecosystem, such as Connect or Streams; use MSK and accept its cost.
- For low-volume queues, where SQS is simpler and cheaper.
