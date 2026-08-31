# Monitoring Module - CloudWatch Alarms and Log Groups
# Creates CloudWatch alarms for RDS monitoring

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "rds" {
  name              = "/aws/rds/instance/${var.db_instance_id}"
  retention_in_days = 30
  
  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-rds-logs"
    }
  )
}

# CPU Utilization Alarm
resource "aws_cloudwatch_metric_alarm" "cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-rds-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.cpu_threshold
  alarm_description   = "This metric monitors RDS CPU utilization"
  alarm_actions       = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []
  
  dimensions = {
    DBInstanceIdentifier = var.db_instance_id
  }
  
  tags = var.tags
}

# Freeable Memory Alarm
resource "aws_cloudwatch_metric_alarm" "memory" {
  alarm_name          = "${var.project_name}-${var.environment}-rds-memory-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FreeableMemory"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.memory_threshold
  alarm_description   = "This metric monitors RDS freeable memory"
  alarm_actions       = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []
  
  dimensions = {
    DBInstanceIdentifier = var.db_instance_id
  }
  
  tags = var.tags
}

# Free Storage Space Alarm
resource "aws_cloudwatch_metric_alarm" "storage" {
  alarm_name          = "${var.project_name}-${var.environment}-rds-storage-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.storage_threshold
  alarm_description   = "This metric monitors RDS free storage space"
  alarm_actions       = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []
  
  dimensions = {
    DBInstanceIdentifier = var.db_instance_id
  }
  
  tags = var.tags
}

# Database Connections Alarm
resource "aws_cloudwatch_metric_alarm" "connections" {
  alarm_name          = "${var.project_name}-${var.environment}-rds-connections-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.connection_threshold
  alarm_description   = "This metric monitors RDS database connections"
  alarm_actions       = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []
  
  dimensions = {
    DBInstanceIdentifier = var.db_instance_id
  }
  
  tags = var.tags
}

# Read Latency Alarm
resource "aws_cloudwatch_metric_alarm" "read_latency" {
  alarm_name          = "${var.project_name}-${var.environment}-rds-read-latency-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ReadLatency"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 0.1 # 100ms
  alarm_description   = "This metric monitors RDS read latency"
  alarm_actions       = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []
  
  dimensions = {
    DBInstanceIdentifier = var.db_instance_id
  }
  
  tags = var.tags
}

# Write Latency Alarm
resource "aws_cloudwatch_metric_alarm" "write_latency" {
  alarm_name          = "${var.project_name}-${var.environment}-rds-write-latency-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "WriteLatency"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 0.1 # 100ms
  alarm_description   = "This metric monitors RDS write latency"
  alarm_actions       = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []
  
  dimensions = {
    DBInstanceIdentifier = var.db_instance_id
  }
  
  tags = var.tags
}

# Disk Queue Depth Alarm
resource "aws_cloudwatch_metric_alarm" "disk_queue" {
  alarm_name          = "${var.project_name}-${var.environment}-rds-disk-queue-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DiskQueueDepth"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 64
  alarm_description   = "This metric monitors RDS disk queue depth"
  alarm_actions       = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []
  
  dimensions = {
    DBInstanceIdentifier = var.db_instance_id
  }
  
  tags = var.tags
}
