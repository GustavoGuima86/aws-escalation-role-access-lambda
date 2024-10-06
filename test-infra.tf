# Create IAM role for test the assume role
resource "aws_iam_role" "rds_access_role" {
  name                 = "rds_access_role"
  max_session_duration = 43200

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

# Create IAM policy for RDS access (write permissions)
resource "aws_iam_policy" "rds_write_policy" {
  name        = "rds_write_policy"
  description = "Policy granting RDS write permissions"

  policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Effect : "Allow",
        Action : [
          "rds:DescribeDBInstances",
          "rds:DescribeDBClusters",
          "rds:ListTagsForResource",
          "rds:DescribeDBSnapshots"
        ],
        Resource : "*"
      },
      {
        Effect : "Allow",
        Action : "rds-db:connect",
        Resource : "*"
      }
    ]
  })
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "rds_access_role_policy_attach" {
  role       = aws_iam_role.rds_access_role.name
  policy_arn = aws_iam_policy.rds_write_policy.arn
}

# Create IAM Group
resource "aws_iam_group" "test_group" {
  name = "test_group"
}

# Create IAM User
resource "aws_iam_user" "test_user" {
  name = "user_test"
  force_destroy = true
}

# Add userTest to testGroup
resource "aws_iam_user_group_membership" "user_group_membership" {
  user = aws_iam_user.test_user.name
  groups = [aws_iam_group.test_group.name]
}