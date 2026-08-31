output "log_group_name" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.rds.name
}

output "log_group_arn" {
  description = "CloudWatch log group ARN"
  value       = aws_cloudwatch_log_group.rds.arn
}

output "alarm_arns" {
  description = "CloudWatch alarm ARNs"
  value = {
    cpu         = aws_cloudwatch_metric_alarm.cpu.arn
    memory      = aws_cloudwatch_metric_alarm.memory.arn
    storage     = aws_cloudwatch_metric_alarm.storage.arn
    connections = aws_cloudwatch_metric_alarm.connections.arn
    read_latency = aws_cloudwatch_metric_alarm.read_latency.arn
    write_latency = aws_cloudwatch_metric_alarm.write_latency.arn
    disk_queue   = aws_cloudwatch_metric_alarm.disk_queue.arn
  }
}
