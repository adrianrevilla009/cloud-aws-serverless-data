# rds-multi-az

Terraform for a Multi-AZ PostgreSQL 16.4 RDS instance on `db.t4g.micro`, with a subnet group and a master password managed by Secrets Manager.

## Goal
Show the settings of a highly available database: a synchronous standby for failover, encryption, backups and a password kept out of state and git.

## Run it
```
terraform init -backend=false
terraform validate
```
Expected: Terraform reports the configuration as valid. This was not run in this pass, so no output is quoted.

Applying needs two real subnets in different availability zones; pass them with `-var 'subnet_ids=["subnet-...","subnet-..."]'` (the defaults are fake IDs). Destroy afterwards with `terraform destroy`.

Not run end to end: Multi-AZ RDS is not in the free tier and nothing was applied. Using real AWS (`-var use_localstack=false`) costs money until destroyed.

## What it proves
- `multi_az = true` creates a standby in a second zone with automatic failover.
- `manage_master_user_password = true` stores the password in Secrets Manager rather than in state.
- Storage is encrypted, backups are kept for 7 days, and the `endpoint` output gives the connection address.

## Trade-offs
- The standby does not serve reads; a read replica is a separate resource.
- `deletion_protection = false` and `skip_final_snapshot = true` make teardown easy but are unsafe for real data.
- The instance has no security group, so network access depends on the VPC default.

## When not to use it
- For development databases, where a single-AZ instance costs half as much.
- For workloads that need read scaling or very fast failover, where Aurora fits better.
