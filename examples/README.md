# Example Root Modules

This directory contains starter root modules that call the Terraform child modules in this repository.

Use these examples when you want a customer-facing starting point that already reflects the recommended root-module pattern.

Available examples:

* [admin-standalone/main.tf](admin-standalone/main.tf) deploys a single Iris Admin instance.
* [admin-ha/main.tf](admin-ha/main.tf) deploys Iris Admin with enterprise HA enabled.
* [anywhere-alb/main.tf](anywhere-alb/main.tf) deploys Iris Anywhere behind an AWS ALB.
* [anywhere-haproxy/main.tf](anywhere-haproxy/main.tf) deploys Iris Anywhere behind HAProxy.

How to use them:

* Copy the closest example into a customer deployment repository or working directory.
* Replace the placeholder subnet IDs, ARNs, key names, and CIDR blocks.
* Keep the top-level locals focused on customer choices.
* Add optional modules such as `es`, `secrets`, or `sqs` only when needed.