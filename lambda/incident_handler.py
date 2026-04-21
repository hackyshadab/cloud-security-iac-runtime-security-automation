

import json
import boto3
import os

sns = boto3.client('sns')
SNS_TOPIC = os.environ['SNS_TOPIC_ARN']

def lambda_handler(event, context):
    print("Received event:", json.dumps(event))

    source = event.get("source")

    # =========================
    # 🛡️ GuardDuty
    # =========================
    if source == "aws.guardduty":
        finding = event.get("detail", {})

        message = f"""
🚨 GuardDuty Alert 🚨
Type: {finding.get('type')}
Severity: {finding.get('severity')}
Description: {finding.get('description')}
Account: {finding.get('accountId')}
Region: {finding.get('region')}
        """

    # =========================
    # 🔐 Security Hub
    # =========================
    elif source == "aws.securityhub":
        findings = event.get("detail", {}).get("findings", [])
        if not findings:
            return {"status": "no findings"}

        f = findings[0]

        message = f"""
🔐 Security Hub Alert 🔐
Title: {f.get('Title')}
Severity: {f.get('Severity', {}).get('Label')}
Resource: {f.get('Resources')[0].get('Id')}
Description: {f.get('Description')}
        """

    # =========================
    # ⚙️ AWS Config
    # =========================
    elif source == "aws.config":
        detail = event.get("detail", {})

        message = f"""
⚙️ AWS Config Change ⚙️
Resource Type: {detail.get('resourceType')}
Resource ID: {detail.get('resourceId')}
Change Type: {detail.get('messageType')}
        """

    else:
        print("Unknown source, ignoring")
        return {"status": "ignored"}

    # Send alert
    sns.publish(
        TopicArn=SNS_TOPIC,
        Subject="🚨 Multi Security Alert",
        Message=message
    )

    return {"status": "alert sent"}