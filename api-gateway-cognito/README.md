# api-gateway-cognito

Terraform for a Cognito user pool and app client, and an API Gateway REST API whose `GET /orders` method requires a Cognito token, deployed to a `dev` stage.

## Goal
Show how a Cognito user pool authorizer protects an API Gateway method, using a mock backend so no compute is needed.

## Run it
```
terraform init -backend=false
terraform validate
```
Expected: Terraform reports the configuration as valid. This was not run in this pass, so no output is quoted.

To apply, start LocalStack and run `terraform apply`, then `terraform destroy`. For real AWS add `-var use_localstack=false`; Cognito and API Gateway are free at this volume.

Not run end to end: no user was signed up and no request was sent, so the 401 and 200 behaviour is untested.

## What it proves
- `aws_api_gateway_authorizer.cognito` is of type `COGNITO_USER_POOLS` and uses the `orders-users` pool.
- `GET /orders` has `authorization = "COGNITO_USER_POOLS"`, so a request without a valid token should be rejected.
- A `MOCK` integration returns status 200, and the deployment redeploys when the method or integration changes.
- The pool requires passwords of at least 12 characters with symbols; the client has no secret and allows SRP and refresh-token flows.

## Trade-offs
- The mock backend returns an empty 200; the comment in `main.tf` says to switch to `AWS_PROXY` for a Lambda.
- The integration response has no body template, so a real client would see no order data.
- Users must be created and confirmed by you; the config provisions none.

## When not to use it
- For public endpoints, where an authorizer only adds latency.
- For HTTP APIs with JWT authorizers, where this REST API setup is heavier than needed.
