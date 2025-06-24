import React from 'react'
import ReactDOM from 'react-dom/client'
import './index.css'
import 'bootstrap/dist/css/bootstrap.min.css';
import App from './App.jsx'
import { AuthProvider } from 'react-oidc-context'

// Debug: Check if token replacement worked
const poolId = "__VITE_COGNITO_POOL_ID__";
const clientId = "__VITE_COGNITO_CLIENT_ID__";
const region = "__VITE_COGNITO_REGION__";
const domain = "__VITE_COGNITO_DOMAIN__";

console.log("🔍 Debug - Pool ID:", poolId);
console.log("🔍 Debug - Client ID:", clientId);
console.log("🔍 Debug - Region:", region);
console.log("🔍 Debug - Domain:", domain);

// Fallback values if tokens weren't replaced
const finalPoolId = poolId.includes("__VITE_") ? "us-east-1_oAPlw1gH4" : poolId;
const finalClientId = clientId.includes("__VITE_") ? "3mpvm5sole4132a8thrlkp43dn" : clientId;
const finalRegion = region.includes("__VITE_") ? "us-east-1" : region;
const finalDomain = domain.includes("__VITE_") ? "https://mercado-close-monkey.auth.us-east-1.amazoncognito.com" : domain;

const cognitoAuthConfig = {
  authority: `https://cognito-idp.${finalRegion}.amazonaws.com/${finalPoolId}`,
  client_id: finalClientId,
  redirect_uri: `${window.location.origin}/login/callback`,
  post_logout_redirect_uri: window.location.origin,
  response_type: "code",
  scope: "openid",
  // If you get scope errors, try these alternatives:
  // scope: "openid email",
  // scope: "openid profile", 
  // scope: "openid email profile",
  automaticSilentRenew: true,
  loadUserInfo: true,
}

console.log("🚀 Final Auth Config:", cognitoAuthConfig);

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <AuthProvider {...cognitoAuthConfig}>
      <App />
    </AuthProvider>
  </React.StrictMode>,
)
