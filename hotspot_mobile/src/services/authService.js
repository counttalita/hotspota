import axios from 'axios';
import AsyncStorage from '@react-native-async-storage/async-storage';

const API_URL = 'http://localhost:4000/api';

// Create axios instance
const api = axios.create({
  baseURL: API_URL,
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Add token to requests if available
api.interceptors.request.use(
  async (config) => {
    const token = await AsyncStorage.getItem('auth_token');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Handle token expiration
api.interceptors.response.use(
  (response) => response,
  async (error) => {
    if (error.response?.status === 401) {
      // Token expired or invalid - clear storage
      await AsyncStorage.removeItem('auth_token');
      await AsyncStorage.removeItem('user_data');
    }
    return Promise.reject(error);
  }
);

export const authService = {
  /**
   * Send OTP to phone number
   */
  async sendOTP(phoneNumber) {
    const response = await api.post('/auth/send-otp', {
      phone_number: phoneNumber,
    });
    return response.data;
  },

  /**
   * Verify OTP and get JWT token
   */
  async verifyOTP(phoneNumber, code) {
    const response = await api.post('/auth/verify-otp', {
      phone_number: phoneNumber,
      code: code,
    });

    const { token, user } = response.data;

    // Store token and user data
    await AsyncStorage.setItem('auth_token', token);
    await AsyncStorage.setItem('user_data', JSON.stringify(user));

    return response.data;
  },

  /**
   * Get current user info
   */
  async getCurrentUser() {
    const response = await api.get('/auth/me');
    const { user } = response.data;

    // Update stored user data
    await AsyncStorage.setItem('user_data', JSON.stringify(user));

    return user;
  },

  /**
   * Get stored token
   */
  async getToken() {
    return await AsyncStorage.getItem('auth_token');
  },

  /**
   * Get stored user data
   */
  async getUserData() {
    const userData = await AsyncStorage.getItem('user_data');
    return userData ? JSON.parse(userData) : null;
  },

  /**
   * Check if user is authenticated
   */
  async isAuthenticated() {
    const token = await this.getToken();
    return !!token;
  },

  /**
   * Logout user
   */
  async logout() {
    await AsyncStorage.removeItem('auth_token');
    await AsyncStorage.removeItem('user_data');
  },
};

export default api;
