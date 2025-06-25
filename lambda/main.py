import base64
import json
import urllib.parse
import urllib.request
import os

CLIENT_ID = os.environ['COGNITO_CLIENT_ID']
CLIENT_SECRET = os.environ['COGNITO_CLIENT_SECRET']
REDIRECT_URI = os.environ['REDIRECT_URI']  # e.g., https://mi-api.com/callback
COGNITO_DOMAIN = os.environ['COGNITO_DOMAIN']  # e.g., my-domain.auth.us-east-1.amazoncognito.com
FRONTEND_URL = os.environ['FRONTEND_URL']  # e.g., https://mi-app.com

def lambda_handler(event, context):
    # 1. Obtener el 'code' del querystring
    params = event.get('queryStringParameters') or {}
    code = params.get('code')
    if not code:
        return {
            'statusCode': 400,
            'body': 'Missing code parameter'
        }

    # 2. Intercambiar el código por tokens
    token_url = f"https://{COGNITO_DOMAIN}/oauth2/token"
    auth_str = f"{CLIENT_ID}:{CLIENT_SECRET}"
    headers = {
        "Authorization": "Basic " + base64.b64encode(auth_str.encode()).decode(),
        "Content-Type": "application/x-www-form-urlencoded"
    }

    data = urllib.parse.urlencode({
        "grant_type": "authorization_code",
        "code": code,
        "redirect_uri": REDIRECT_URI
    }).encode()

    req = urllib.request.Request(token_url, data=data, headers=headers)
    
    try:
        with urllib.request.urlopen(req) as res:
            body = res.read()
            token_data = json.loads(body)

        # 3. Redirigir al frontend con los tokens en la URL hash
        redirect_url = (
            f"{FRONTEND_URL}#"
            f"access_token={token_data['access_token']}"
            f"&id_token={token_data['id_token']}"
            f"&refresh_token={token_data.get('refresh_token', '')}"
        )

        return {
            "statusCode": 302,
            "headers": {
                "Location": redirect_url
            },
            "body": ""
        }

    except Exception as e:
        print("Error exchanging token:", str(e))
        return {
            'statusCode': 500,
            'body': 'Failed to exchange code for tokens.'
        }
