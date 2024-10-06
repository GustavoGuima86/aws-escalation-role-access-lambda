import json
import boto3
from datetime import datetime, timedelta
from botocore.exceptions import ClientError

iam_client = boto3.client('iam')
scheduler_client = boto3.client('scheduler')
lambda_client = boto3.client('lambda')

def lambda_handler(event, context):
    # Extract input parameters
    role_name = event['role_name'] # Role to be removed
    user_arns = event['user_arns'] # List of user ARNs
    message = event['message'] # Message with explain the purpose and possibly a Ticket number assigned for

    return remove_users_from_role(role_name, user_arns, message)

# Remove IAM users from the role's trust policy
def remove_users_from_role(role_name, user_arns, message):
    try:
        # Step 1: Get the current trust policy of the role
        response = iam_client.get_role(RoleName=role_name)
        assume_role_policy = response['Role']['AssumeRolePolicyDocument']

        # Step 2: Filter out the users from the trust policy
        new_policy_statements = [
            statement for statement in assume_role_policy['Statement']
            if 'AWS' not in statement['Principal'] or statement['Principal']['AWS'] not in user_arns
        ]
        assume_role_policy['Statement'] = new_policy_statements

        # Step 3: Update the trust policy
        iam_client.update_assume_role_policy(
            RoleName=role_name,
            PolicyDocument=json.dumps(assume_role_policy)
        )
        # Step 4: Log the changes
        print(message)

        return {
            'statusCode': 200,
            'body': json.dumps(message)
        }

    except ClientError as e:
        print(f"Error removing users from role: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps(f"Error: {e}")
        }