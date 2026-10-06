# cloud-aws-serverless-data

Eight small Terraform configurations that wire the main AWS serverless and data services around a shared Orders domain, each runnable against LocalStack or, where the cost is stated, real AWS.

## What is inside

| Folder | What it shows | Run |
| --- | --- | --- |
| [`lambda-snapstart`](./lambda-snapstart) | Java 21 Lambda with SnapStart on published versions, called through an alias | `terraform init -backend=false && terraform validate` |
| [`sqs-sns-eventbridge`](./sqs-sns-eventbridge) | SNS fan-out to an SQS queue with a dead-letter queue, plus an EventBridge rule for large orders | `terraform init -backend=false && terraform validate` |
| [`step-functions`](./step-functions) | Standard state machine with Choice, Wait, Succeed and Fail states | `terraform init -backend=false && terraform validate` |
| [`api-gateway-cognito`](./api-gateway-cognito) | REST API whose `GET /orders` is protected by a Cognito user pool authorizer | `terraform init -backend=false && terraform validate` |
| [`rds-multi-az`](./rds-multi-az) | Multi-AZ PostgreSQL instance with a managed master password | `terraform init -backend=false && terraform validate` |
| [`s3-event-pipeline`](./s3-event-pipeline) | S3 upload notifications for `incoming/*.csv` delivered to an SQS queue | `terraform init -backend=false && terraform validate` |
| [`dynamodb-streams`](./dynamodb-streams) | DynamoDB stream feeding a Lambda with partial-batch failure handling and an SQS failure destination | `terraform init -backend=false && terraform validate` |
| [`msk-kinesis-streaming`](./msk-kinesis-streaming) | On-demand Kinesis stream with an enhanced fan-out consumer (MSK is explained but not declared) | `terraform init -backend=false && terraform validate` |

Run each command from inside its folder. Every folder pins the AWS provider to 5.100.0 and uses the same Orders example.

## Prerequisites

- Terraform 1.9 or newer (below 2.0).
- LocalStack (Docker) to apply the configurations locally; the default `use_localstack = true` points the provider at `http://localhost:4566` with dummy credentials.
- For `lambda-snapstart` and `dynamodb-streams`: a Java 21 shaded jar at the path given by the `jar_path` variable, built by you.
- An AWS account only if you set `-var use_localstack=false`; run `terraform destroy` afterwards.

## How to read it

Start with `sqs-sns-eventbridge` or `s3-event-pipeline`, which are fully self-contained, then move to `dynamodb-streams` and `lambda-snapstart`, which also need a jar. The validate command checks syntax and provider schemas only; the folder READMEs say what was and was not applied.
