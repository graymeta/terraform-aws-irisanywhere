###############################################################################
# indexer.tf
###############################################################################

locals {
  indexer_domain = (
    var.custom_endpoint_enabled
    ? var.custom_endpoint
    : aws_opensearch_domain.es.endpoint
  )

  initial_index_script = <<-POWERSHELL
    $ErrorActionPreference = "Stop"

    $buckets = @(
    ${join("\n", [
      for bucket in sort(tolist(local.current_region_buckets)) :
      "    '${bucket}'"
    ])}
    )

    $region    = "${data.aws_region.current.region}"
    $domain    = "${local.indexer_domain}"
    $osRoleArn = "${aws_iam_role.s3_indexer_role.arn}"
    $indexer   = "C:\\ProgramData\\GrayMeta\\functions\\s3-index.exe"

    Write-Host "=================================================="
    Write-Host "Starting initial S3 indexing"
    Write-Host "Region:       $region"
    Write-Host "Domain:       $domain"
    Write-Host "OS Role ARN:  $osRoleArn"
    Write-Host "Bucket Count: $($buckets.Count)"
    Write-Host "=================================================="

    if (-not (Test-Path $indexer)) {
        throw "Indexer executable not found: $indexer"
    }

    foreach ($bucket in $buckets) {

        Write-Host ""
        Write-Host "Indexing bucket: $bucket"

        & $indexer `
            --region $region `
            --bucket $bucket `
            --domain $domain `
            --osRoleArn $osRoleArn

        if ($LASTEXITCODE -ne 0) {
            throw "s3-index.exe failed for bucket '$bucket' with exit code $LASTEXITCODE"
        }

        Write-Host "Completed bucket: $bucket"
    }

    Write-Host ""
    Write-Host "Initial S3 indexing completed successfully."
  POWERSHELL
}


resource "aws_ssm_association" "initial_s3_index" {
  name             = "AWS-RunPowerShellScript"
  association_name = "initial-s3-index-${replace(var.domain, ".", "-")}"

  targets {
    key    = "InstanceIds"
    values = [var.admin_instance_id]
  }

  parameters = {
    commands = local.initial_index_script
  }

  # Terraform waits for the association execution to succeed.
  # Increase this if indexing can take a long time.
  wait_for_success_timeout_seconds = 3600

  depends_on = [
    aws_opensearch_domain.es,
    aws_opensearch_domain_policy.iris_s3,

    aws_lambda_function.update-es-index-lambda,

    aws_iam_role.s3_indexer_role,
    aws_iam_role_policy_attachment.s3_indexer_policy_att,
    aws_iam_role_policy_attachment.AWSLambdaVPCAccessExecutionRole,
    aws_iam_role_policy_attachment.AWSLambdaBasicExecutionRole,

    aws_lambda_permission.s3objectperm,
    aws_s3_bucket_notification.s3object_events
  ]
}