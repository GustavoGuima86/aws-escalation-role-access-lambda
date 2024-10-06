# Creating the zip file from the Lambda
data "archive_file" "add_user_to_lambda" {
  type        = "zip"
  source_file = "lambdas/add-user-to-role-lambda.py"
  output_path = "lambdas/add-user-to-role-lambda.zip"
}

# Lambda definition, attaching the role and input the Environment variables to be used to
resource "aws_lambda_function" "add_assume_role_lambda" {
  filename         = "lambdas/add-user-to-role-lambda.zip"
  function_name    = "AddAssumeRoleLambda"
  role             = aws_iam_role.lambda_role_add_user.arn
  handler          = "add-user-to-role-lambda.lambda_handler"
  runtime          = "python3.8"
  timeout          = 30
  source_code_hash = data.archive_file.add_user_to_lambda.output_base64sha256
  environment {
    variables = {
      EVENT_BRIDGE_LAMBDA_ROLE = aws_iam_role.scheduler_role.arn,
      REMOVE_USER_LAMBDA_ARN   = aws_lambda_function.remove_assume_role_lambda.arn
    }
  }
}

# Lambda IAM role for the add role lambda
resource "aws_iam_role" "lambda_role_add_user" {
  name = "lambda_role_add_user"

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
resource "aws_iam_policy" "lambda_iam_policy_add_user" {
  name        = "lambda_iam_policy_add_user"
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
          "scheduler:CreateSchedule",
          "logs:PutLogEvents",
          "logs:CreateLogGroup",
          "logs:CreateLogStream"
        ],
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = "lambda:InvokeFunction",
        Resource = "*" # Can be defined a restrict group/user allowed to execute this lambda
      }
    ]
  })
}

# Attach the IAM policy to the Lambda role
resource "aws_iam_role_policy_attachment" "lambda_policy_attach_add_user" {
  role       = aws_iam_role.lambda_role_add_user.name
  policy_arn = aws_iam_policy.lambda_iam_policy_add_user.arn
}


# Role to ne used by the Scheduler allowing this to execute the lambda
resource "aws_iam_role" "scheduler_role" {
  name = "eventbridge_scheduler_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "scheduler.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Policy to ne used by the Scheduler allowing this to execute the lambda
resource "aws_iam_role_policy" "scheduler_invoke_lambda_policy" {
  role = aws_iam_role.scheduler_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "lambda:InvokeFunction",
        Resource = "*"
      }
    ]
  })
}