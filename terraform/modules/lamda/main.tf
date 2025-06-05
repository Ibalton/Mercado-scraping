# Create a CloudWatch EventBridge rule that runs every day at midnight UTC
resource "aws_cloudwatch_event_rule" "daily_schedule" {
  name                = "daily-scraper-trigger"
  description         = "Trigger the scraper lambda every day"
  schedule_expression = "cron(0 0 * * ? *)"
}

# Set the EventBridge rule to trigger your Lambda function
resource "aws_cloudwatch_event_target" "scraper_lambda_target" {
  rule      = aws_cloudwatch_event_rule.daily_schedule.name
  target_id = "scraperLambda"
  arn       = aws_lambda_function.scraper_lambda.arn
}

# Grant EventBridge permission to invoke the Lambda function
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.scraper_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.daily_schedule.arn
}