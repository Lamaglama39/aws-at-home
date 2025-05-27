data "aws_caller_identity" "current" {}

resource "aws_iam_role" "main" {
  name = "ssm-agent-homeserver-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ssm.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "use_kms_key" {
  name        = "ssm-agent-homeserver-use-kms-key-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "kms:Decrypt"
        Effect   = "Allow"
        Resource = aws_kms_key.main.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "use_kms_key" {
  role       = aws_iam_role.main.name
  policy_arn = aws_iam_policy.use_kms_key.arn
}

resource "aws_iam_role_policy_attachment" "ssm_instance_core" {
  role       = aws_iam_role.main.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_ssm_activation" "main" {
  name               = "ssm-agent-homeserver-activation"
  iam_role           = aws_iam_role.main.id
  registration_limit = "6"
  depends_on         = [aws_iam_role_policy_attachment.ssm_instance_core]
}

resource "aws_kms_key" "main" {
  deletion_window_in_days = 7
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })
}

output "kms_key_arn" {
  value = aws_kms_key.main.arn
}

output "activation_id" {
  value = aws_ssm_activation.main.id
  sensitive = true
}

output "activation_code" {
  value = aws_ssm_activation.main.activation_code
  sensitive = true
}
