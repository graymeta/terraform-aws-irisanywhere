# GrayMeta Iris Anywhere OpenSearch Helpers

This directory currently contains helper content for OpenSearch-related workflows, not a standalone Terraform module with its own variable interface.

If you want to provision the search domain itself, use the `es` Terraform module documented in [../es/README.md](../es/README.md).

This directory is useful for:

* indexing and update helper workflows,
* OpenSearch integration experiments,
* operational utilities that sit alongside the main `es` deployment module.

Contents:

* `indexS3Bucket/` helper content for S3 indexing workflows.
* `updateESindex/` helper content for updating search indexes.

If this directory is intended to become a first-class Terraform module later, it should gain its own Terraform files, documented inputs, documented outputs, and usage examples.
