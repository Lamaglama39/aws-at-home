resource "aws_iam_user" "main" {
  name = "cloudwatch-agent-homeserver-user"
}

resource "aws_iam_access_key" "main" {
  user = aws_iam_user.main.name
}

resource "aws_iam_user_policy_attachment" "main" {
  user       = aws_iam_user.main.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_ssm_parameter" "secret" {
  name        = "AmazonCloudWatch-HomeServer-Config"
  type        = "String"
  value       = file("${path.module}/amazon-cloudwatch-agent.json")
}

output "iam_user_access_key_id" {
  value = aws_iam_access_key.main.id
  sensitive = true
}

output "iam_user_access_key_secret" {
  value = aws_iam_access_key.main.secret
  sensitive = true
}
