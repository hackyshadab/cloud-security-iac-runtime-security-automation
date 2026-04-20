import json
import boto3
import os

sns = boto3.client('sns')

SNS_TOPIC = os.environ['SNS_TOPIC_ARN']

def lambda_handler(event, context):
    print("Received event:", json.dumps(event))

    finding = event.get("detail", {})
    
    message = f"""
🚨 GuardDuty Alert 🚨

Type: {finding.get('type')}
Severity: {finding.get('severity')}
Description: {finding.get('description')}
Account: {finding.get('accountId')}
Region: {finding.get('region')}
    """

    sns.publish(
        TopicArn=SNS_TOPIC,
        Subject="🚨 Security Alert",
        Message=message
    )

    return {"status": "alert sent"}