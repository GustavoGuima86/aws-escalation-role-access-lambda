# aws-escalation-role-access-lambda

Method for Escalating Access Using STS Assume Role with Lambda and Automated Access Removal

We can implement a process to temporarily grant users elevated access using AWS STS (Security Token Service) 
assume role, leveraging two Python-based Lambda functions and a one-time scheduler. This approach allows us to
provide temporary access to users via STS and automatically revoke their permissions after a defined period, 
ensuring controlled and time-limited access escalation.

The first Lambda function, add-user-to-role-lambda.py, is responsible for assigning a specified role to a user 
based on the provided user ARN, message, and Time-to-Live (TTL). It grants the user access to assume the role 
for the duration defined by the TTL. Additionally, this Lambda function schedules a callback to invoke the 
second Lambda function after the TTL expires.

The second Lambda function, remove-user-from-role-lambda.py, is triggered by the scheduler and handles the 
removal of the specified users from the role once the TTL has elapsed.



## Deployment

``terraform init``

``terraform plan``

``terraform apply``

## request example

An example of request for the lambda to use in the lambda

```
{
  "role_name": "rds_access_role",
  "user_arns": [
    "arn:aws:iam::156041418374:user/test-user"
  ],
  "purpose": "test with ticket BLA-123",
  "ttl": 90
}
```