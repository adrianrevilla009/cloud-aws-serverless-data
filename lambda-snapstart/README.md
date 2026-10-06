# lambda-snapstart

Terraform for a Java 21 Orders Lambda with SnapStart enabled, published as a version and exposed through a `live` alias.

## Goal
Show the three settings that make SnapStart take effect: `snap_start` on published versions, `publish = true`, and an alias that callers use instead of `$LATEST`.

## Run it
```
terraform init -backend=false
terraform validate
```
Expected: Terraform reports the configuration as valid. This was not run in this pass, so no output is quoted.

To apply, start LocalStack, build a jar and point `jar_path` at it (default `build/orders-handler.jar`), then `terraform apply` and later `terraform destroy`. For real AWS add `-var use_localstack=false`; Lambda and IAM at this size cost only invocations.

Not run end to end: no jar is included, and LocalStack does not emulate snapshot restore, so no cold-start numbers exist.

## What it proves
- `main.tf` sets `snap_start { apply_on = "PublishedVersions" }` together with `publish = true`, the pair AWS requires.
- `aws_lambda_alias.live` points at the published version, and the `alias_arn` output is the ARN callers should invoke.
- The function uses the `java21` runtime, 1024 MB of memory and a 10 s timeout, with `source_code_hash` taken from the jar when it exists.

## Trade-offs
- SnapStart only applies to published versions, so every code change needs a new version and an alias update.
- Code must tolerate restore: re-seed randomness and refresh connections and credentials after the snapshot is resumed.
- The execution role has no policies attached, so the function cannot write logs until you add them.

## When not to use it
- For runtimes that already start fast, such as Node or Go.
- For functions where provisioned concurrency already removes cold starts and SnapStart adds nothing.
