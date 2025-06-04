variable "hosts" {
  default = ["server-01", "server-02", "server-03", "server-04", "server-05", "server-06"]
}

resource "aws_cloudwatch_metric_alarm" "mem_used_alarm" {
  for_each = toset(var.hosts)

  alarm_name          = "mem_used_${each.key}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "mem_used"
  namespace           = "CWAgent"
  period              = 60
  statistic           = "Average"
  threshold           = 2e+09
  alarm_description   = "Memory usage alarm for ${each.key}"
  dimensions = {
    host = each.key
  }
  actions_enabled     = false
}
