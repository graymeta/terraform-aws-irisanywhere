locals {
  default_tags = {
    source  = "terraform"
    cluster = replace("${var.hostname_prefix}-${var.deployment_name != "1" ? var.deployment_name : var.instance_type}", ".", "")
  }

  merged_tags = merge(var.tags, local.default_tags)

  # rclone warm scripts, with comment and blank lines stripped to keep the user data under 16 KB
  rclone_warm_scripts = {
    for f in ["rclone-autowarm.ps1", "rclone-prewarm.ps1"] :
    f => replace(replace(file("${path.module}/rclone-warm/${f}"), "/(?m)^[ \\t]*#.*\\r?\\n/", ""), "/(?m)^[ \\t]*\\r?\\n/", "")
  }

  iris_user_data = join("\n", ["<powershell>", templatefile("${path.module}/cloud_local.ps1", {
    name                      = replace("${var.hostname_prefix}-${var.deployment_name != "1" ? var.deployment_name : var.instance_type}", ".", "")
    metric_check_interval     = var.asg_check_interval
    health_check_interval     = var.lb_check_interval
    unhealthy_threshold       = var.lb_unhealthy_threshold
    cooldown                  = var.asg_scalein_cooldown
    ia_cert_crt_arn           = var.ia_cert_crt_arn
    ia_cert_key_arn           = var.ia_cert_key_arn
    ia_max_sessions           = var.ia_max_sessions
    ia_keepalivetimeout       = var.ia_keepalivetimeout
    ia_secret_arn             = var.ia_secret_arn
    ia_domain                 = var.ia_domain
    search_enabled            = var.search_enabled
    ia_video_bitrate          = var.ia_video_bitrate
    ia_video_codec            = var.ia_video_codec
    s3_enterprise             = var.s3_enterprise
    haproxy                   = var.haproxy
    saml_enabled              = var.saml_enabled
    saml_cert_secret_arn      = var.saml_cert_secret_arn
    disk_data_size            = var.disk_data_size
    otlp_enabled              = var.otlp_enabled
    otlp_exporter_destination = var.otlp_exporter_destination
    wasabi                    = var.wasabi
    file_warm                 = var.file_warm
    rclone_warm_max_age       = var.rclone_warm_max_age
    rclone_warm_watcher       = var.s3_enterprise && var.file_warm ? base64gzip(local.rclone_warm_scripts["rclone-autowarm.ps1"]) : ""
    rclone_warm_prewarm       = var.s3_enterprise && var.file_warm ? base64gzip(local.rclone_warm_scripts["rclone-prewarm.ps1"]) : ""
  }), var.user_init, "\n", "Restart-Computer -Force", "\n", "</powershell>"])
}
