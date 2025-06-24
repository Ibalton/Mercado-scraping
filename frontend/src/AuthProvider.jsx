import React, { createContext, useState, useEffect } from 'react';
import axiosClient from './axiosClient';

export const AuthContext = createContext({ user: null, loading: true, error: null });

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    const checkAuth = async () => {
      try {
        const response = await axiosClient.get('/me');
        setUser(response.data);
        setError(null);
      } catch (err) {
        console.log('Auth check:', err.response?.status || 'Network error');
        setUser(null);
        
        // Only set error for non-authentication errors
        if (err.response?.status === 401 || err.response?.status === 403) {
          // 401/403 just means not logged in - this is expected
        } else if (!err.response) {
          // Network error - likely CORS or backend down
          setError('Unable to connect to server. Please check if the backend is running.');
        } else {
          // Other HTTP errors
          setError(`Server error: ${err.response?.data?.detail || err.message}`);
        }
      } finally {
        setLoading(false);
      }
    };

    checkAuth();
  }, []); // Only run once on mount

  return (
    <AuthContext.Provider value={{ user, setUser, loading, error }}>
      {children}
    </AuthContext.Provider>
  );
}; 