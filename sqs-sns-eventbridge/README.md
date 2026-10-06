# sqs-sns-eventbridge

Terraform for an Orders SNS topic fanning out to an SQS billing queue with a dead-letter queue, plus an EventBridge rule that routes large orders to the same queue.

## Goal
Contrast two ways of delivering events: SNS fan-out to every subscriber, and EventBridge content filtering that forwards only matching events.

## Run it
```
terraform init -backend=false
terraform validate
```
Expected: Terraform reports the configuration as valid. This was not run in this pass, so no output is quoted.

To apply, start LocalStack and run `terraform apply`, then `terraform destroy`. For real AWS add `-var use_localstack=false`; these services are free at this volume.

Not run end to end: nothing was published to the topic or the bus, so message delivery and the DLQ redrive are untested.

## What it proves
- `orders-events` delivers raw messages (`raw_message_delivery = true`) to the `billing` queue.
- `billing` moves a message to `billing-dlq` after 3 receives (`maxReceiveCount = 3`).
- The `large-orders` rule on the `orders` bus matches only `shop.orders` / `OrderPlaced` events with `detail.total >= 1000`.
- One queue policy in `main.tf` allows both `sns.amazonaws.com` and `events.amazonaws.com`, each restricted by `aws:SourceArn`.

## Trade-offs
- Billing receives events from two sources with different payload shapes (raw SNS message vs EventBridge envelope), which the consumer must handle.
- The DLQ has no alarm or redrive configuration here.
- The queues are standard, so ordering is not guaranteed and duplicates are possible.

## When not to use it
- When you need strict ordering; use FIFO topics and queues instead.
- When a single producer and consumer are enough; a plain queue is simpler.
