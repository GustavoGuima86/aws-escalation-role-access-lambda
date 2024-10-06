# Creating the zip file from the Lambda
data "archive_file" "remove_user_to_lambda" {
  type        = "zip"
  source_file = "lambdas/remove-user-to-role-lambda.py"
  output_path = "lambdas/remove-user-to-role-lambda.zip"
}

# Lambda definition and attaching the role
resource "aws_lambda_function" "remove_assume_role_lambda" {
  filename         = "lambdas/remove-user-to-role-lambda.zip"
  function_name    = "RemoveAssumeRoleLambda"
  role             = aws_iam_role.lambda_role_remove_user.arn
  handler          = "remove-user-to-role-lambda.lambda_handler"
  runtime          = "python3.8"
  timeout          = 30
  source_code_hash = data.archive_file.remove_user_to_lambda.output_base64sha256
}

# Lambda IAM role for the Remove Role Lambda
resource "aws_iam_role" "lambda_role_remove_user" {
  name = "lambda_role_remove_user"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Define the IAM policy for Lambda permissions
resource "aws_iam_policy" "lambda_iam_policy_remove_user" {
  name        = "lambda_iam_policy_remove_user"
  description = "IAM policy for Lambda to manage IAM roles and EventBridge rules"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "iam:GetRole",
          "iam:PassRole",
          "iam:UpdateAssumeRolePolicy",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = "lambda:InvokeFunction",
        Resource = "*"
      }
    ]
  })
}

# Attach the IAM policy to the Lambda role
resource "aws_iam_role_policy_attachment" "lambda_policy_attach_remove_user" {
  role       = aws_iam_role.lambda_role_remove_user.name
  policy_arn = aws_iam_policy.lambda_iam_policy_remove_user.arn
}
