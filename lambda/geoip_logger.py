import json
import requests
import os
import boto3
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['DDB_TABLE'])

def lambda_handler(event, context):
    # Get requester's IP address
    ip = event['headers'].get('X-Forwarded-For', '').split(',')[0].strip()

    # Fetch geolocation info
    geo = requests.get(f"https://ipapi.co/{ip}/json/").json()

    # Format item
    item = {
        "ip": ip,
        "timestamp": datetime.utcnow().isoformat(),
        "city": geo.get("city", "Unknown"),
        "country": geo.get("country_name", "Unknown"),
        "user_agent": event['headers'].get('User-Agent', 'Unknown')
    }

    # Write to DynamoDB
    table.put_item(Item=item)

    return {
        "statusCode": 200,
        "body": json.dumps({"message": "IP logged successfully!", "ip": ip, "location": geo})
    }
