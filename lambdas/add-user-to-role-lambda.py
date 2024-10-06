import os
import json
import boto3
from datetime import datetime, timedelta
from botocore.exceptions import ClientError

# Modules used
iam_client = boto3.client('iam')
scheduler_client = boto3.client('scheduler')
lambda_client = boto3.client('lambda')

def lambda_handler(event, context):
    # Extract input parameters
    role_name = event['role_name'] # Role to be assumed
    user_arns = event['user_arns'] # List of user ARNs
    ttl = event.get('ttl', 3600) # TTL for the role be assumed
    purpose = event['purpose'] # Message with explain the purpose and possibly a Ticket number assigned for

    # Environment variables to be used
    eventbridge_scheduler_lambda_role = os.environ['EVENT_BRIDGE_LAMBDA_ROLE'] # Role to be assumed by the scheduler
    remove_user_lambda_arn = os.environ['REMOVE_USER_LAMBDA_ARN'] # ARN for the lambda to be called by the scheduler to remove the user

    return add_users_to_role(role_name, user_arns, ttl, purpose, eventbridge_scheduler_lambda_role, remove_user_lambda_arn)

# Add IAM users to the role's trust policy
def add_users_to_role(role_name, user_arns, ttl, purpose, eventbridge_scheduler_lambda_role, remove_user_lambda_arn):
    try:
        # Step 1: Get the current trust policy of the role
        response = iam_client.get_role(RoleName=role_name)
        assume_role_policy = response['Role']['AssumeRolePolicyDocument']

        # Step 2: Modify the trust policy to add the user ARNs
        for user_arn in user_arns:
            assume_role_policy['Statement'].append({
                "Effect": "Allow",
                "Principal": {
                    "AWS": user_arn
                },
                "Action": "sts:AssumeRole"
            })

        # Step 3: Update the trust policy with the new users
        iam_client.update_assume_role_policy(
            RoleName=role_name,
            PolicyDocument=json.dumps(assume_role_policy)
        )
        # Step 4: Log the changes
        print(f"Users {user_arns} can now assume the role {role_name} for the purpose {purpose}")

        # Step 5: Schedule removal after TTL using EventBridge rule
        schedule_user_removal(role_name, user_arns, ttl, purpose, remove_user_lambda_arn, eventbridge_scheduler_lambda_role)
        return {
            'statusCode': 200,
            'body': json.dumps(f"Users {user_arns} added to role {role_name} with TTL {ttl} seconds")
        }

    except ClientError as e:
        print(f"Error adding users to role: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps(f"Error: {e}")
        }

# Schedule the removal of users after TTL using EventBridge
def schedule_user_removal(role_name, user_arns, ttl, purpose, remove_user_lambda_arn, eventbridge_scheduler_lambda_role):
    try:
        # Step 1: Calculate the removal time (current time + TTL)
        remove_time = (datetime.utcnow() + timedelta(seconds=ttl)).strftime('%Y-%m-%dT%H:%M:%S')

        # Step 2: Define a unique schedule name
        schedule_name = f"RemoveUsersFromRole-{role_name}-{int(datetime.utcnow().timestamp())}"

        # Step 3: Schedule Lambda invocation using the EventBridge Scheduler
        response = scheduler_client.create_schedule(
            Name=schedule_name,
            ScheduleExpression=f"at({remove_time})",
            FlexibleTimeWindow={'Mode': 'OFF'},  # Ensures the event happens at exactly the time
            Target={
                'Arn': remove_user_lambda_arn, # The lambda to be called to remove the user
                'RoleArn': eventbridge_scheduler_lambda_role, # The role for EventBridge Scheduler
                'Input': json.dumps({
                    'role_name': role_name, # Role to remove the user
                    'user_arns': user_arns, # user(s) to be removed
                    'message': f'Removing role {role_name} for the users {user_arns} with the purpose of {purpose} '
                })
            }
        )

        # Step 4: Log the changes
        print(f"Scheduled removal of users {user_arns} from role {role_name} at {remove_time}")
        return True

    except ClientError as e:
        print(f"Error scheduling user removal: {e}")
        return False