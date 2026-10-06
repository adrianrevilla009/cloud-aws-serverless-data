# step-functions

Terraform for a Standard Step Functions state machine, `order-workflow`, defined inline in JSON through `jsonencode`, with its IAM role.

## Goal
Show an approval-style workflow built from Choice, Wait, Succeed and Fail states, and how Terraform declares it.

## Run it
```
terraform init -backend=false
terraform validate
```
Expected: Terraform reports the configuration as valid. This was not run in this pass, so no output is quoted.

To apply, start LocalStack and run `terraform apply`, then `terraform destroy`. For real AWS add `-var use_localstack=false`; state transitions cost a small amount beyond the free allowance.

Not run end to end: no execution was started, so the branches below are read from the definition, not observed.

## What it proves
- `Validate` sends input without `$.total` to `Reject`, a Fail state with error `OrderRejected`.
- `CheckTotal` sends totals above 1000 to `WaitForApproval` (a 5 s Wait) and everything else straight to `Accept`.
- The `state_machine_arn` output gives the ARN to pass to `aws stepfunctions start-execution`.

## Trade-offs
- The Wait state stands in for a real human approval; production flows use a task token callback.
- The role has a trust policy for `states.amazonaws.com` but no permissions, so it cannot call other services yet.
- The definition lives in HCL as JSON, so there is no Amazon States Language validation before apply.

## When not to use it
- For a single short step or one Lambda call, where orchestration adds cost and moving parts.
- For high-volume, short-lived workflows, where Express workflows are the cheaper type.
