import json
import boto3

dynamodb = boto3.resource('dynamodb')
table_name = 'resume_visitor'
table = dynamodb.Table(table_name)



def displayname():
    print("Rogmer Delacruz Bulaclac")

def lambda_handler(event, context):
    
    try:
        client_ip = event['requestContext']['identity']['sourceIp']
        # Check if the IP address is already in the database
        existing_visitor = table.get_item(
            Key={'ip': client_ip}
        )

        if 'Item' not in existing_visitor:
            # If the IP address is not in the database, add a new entry
            table.put_item(
                Item={'ip': client_ip}
            )

        # Get the count of unique visitors
        response = table.scan(Select='COUNT')
        
        
        return  {
            'statusCode': 200,
             'headers': {
                "Access-Control-Allow-Headers" : "Content-Type",
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "OPTIONS,POST,GET"
            },
            'body': f'{response["Count"]}'
         }
        
      
    except Exception as e:
        print(f'Error1: {e}')
        return {
            'statusCode': 500,
            'body': 'Internal Server Error'
        }



