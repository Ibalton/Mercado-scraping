import os

COGNITO_POOL_ID  = os.getenv("COGNITO_POOL_ID", "")
print("COGNITO_POOL_ID", COGNITO_POOL_ID)
COGNITO_CLIENT_ID = os.getenv("COGNITO_CLIENT_ID", "")
COGNITO_REGION   = os.getenv("COGNITO_REGION", "us-east-1")

# Build Cognito hosted domain URL only if pool id is provided to avoid malformed URLs in local dev
if COGNITO_POOL_ID:
    COGNITO_DOMAIN   = f"https://{COGNITO_POOL_ID}.auth.{COGNITO_REGION}.amazoncognito.com"
else:
    COGNITO_DOMAIN = ""

# OAuth callback as implemented by FastAPI route
REDIRECT_URI     = "/auth/callback"

# Session cookie name
COOKIE_NAME      = "session"

# Development mode - bypasses authentication when set to "true"
DEV_MODE = os.getenv("DEV_MODE", "false").lower() == "true"

# In-memory cache for Cognito JWKs.  Keys persist for the process lifetime.
JWT_KID_CACHE    = {} 