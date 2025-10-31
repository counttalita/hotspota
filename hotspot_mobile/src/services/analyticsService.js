import axios from 'axios';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { API_URL } from './config';

// Create axios instance with default config
const api = axios.create({
  baseURL: API_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Add auth token to requests
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

export const analyticsService = {
  /**
   * Get top 5 hotspot areas with highest incident counts
   * Requires premium subscription
   * @returns {Promise<Array>} Array of hotspot areas
   */
  async getTopHotspots() {
    try {
      const response = await api.get('/analytics/hotspots');
      return response.data.data;
    } catch (error) {
      console.error('Error fetching hotspots:', error.response?.data || error.message);
      throw error;
    }
  },

  /**
   * Get time pattern analysis showing peak hours for each incident type
   * @returns {Promise<Array>} Array of hourly patterns
   */
  async getTimePatterns() {
    try {
      const response = await api.get('/analytics/time-patterns');
      return response.data.data;
    } catch (error) {
      console.error('Error fetching time patterns:', error.response?.data || error.message);
      throw error;
    }
  },

  /**
   * Get weekly trend data showing incident counts over time
   * @param {number} [weeks=4] - Number of weeks to analyze
   * @returns {Promise<Array>} Array of weekly trend data
   */
  async getWeeklyTrends(weeks = 4) {
    try {
      const response = await api.get('/analytics/trends', {
        params: { weeks },
      });
      return response.data.data;
    } catch (error) {
      console.error('Error fetching trends:', error.response?.data || error.message);
      throw error;
    }
  },

  /**
   * Get overall analytics summary
   * @returns {Promise<Object>} Summary statistics
   */
  async getSummary() {
    try {
      const response = await api.get('/analytics/summary');
      return response.data.data;
    } catch (error) {
      console.error('Error fetching summary:', error.response?.data || error.message);
      throw error;
    }
  },
};
