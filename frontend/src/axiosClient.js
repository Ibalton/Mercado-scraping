// src/axiosClient.js
import axios from 'axios';

// VITE_API_URL is injected at runtime via entrypoint.sh
// The build uses a placeholder token that gets replaced with the actual URL from ECS environment
const backendUrl = import.meta.env.VITE_API_URL || 'http://localhost:8000';

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

