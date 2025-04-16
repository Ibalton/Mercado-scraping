// src/axiosClient.js
import axios from 'axios';

// You can use an environment variable (e.g., REACT_APP_BACKEND_URL) to manage the URL.
// In .env file add: REACT_APP_BACKEND_URL=http://localhost:8000
const backendUrl = 'http://localhost:8000';

const axiosClient = axios.create({
  baseURL: backendUrl,
  headers: {
    'Content-Type': 'application/json'
  }
});

// Optionally, you can add interceptors for requests/responses
axiosClient.interceptors.request.use(
  (config) => {
    // e.g., add authorization token if available
    // config.headers.Authorization = 'Bearer token';
    return config;
  },
  (error) => Promise.reject(error)
);

axiosClient.interceptors.response.use(
  (response) => response,
  (error) => Promise.reject(error)
);

export default axiosClient;

