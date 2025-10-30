import axios from 'axios';
import AsyncStorage from '@react-native-async-storage/async-storage';

const API_URL = 'http://localhost:4000/api';

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

export const incidentService = {
  /**
   * Create a new incident report
   * @param {Object} incidentData - The incident data
   * @param {string} incidentData.type - Type of incident (hijacking, mugging, accident)
   * @param {number} incidentData.latitude - Latitude coordinate
   * @param {number} incidentData.longitude - Longitude coordinate
   * @param {string} [incidentData.description] - Optional description
   * @param {string} [incidentData.photo_url] - Optional photo URL
   * @returns {Promise<Object>} The created incident
   */
  async create(incidentData) {
    try {
      const response = await api.post('/incidents', {
        incident: incidentData,
      });
      return response.data.data;
    } catch (error) {
      console.error('Error creating incident:', error.response?.data || error.message);
      throw error;
    }
  },

  /**
   * Get incidents near a location
   * @param {number} latitude - Latitude coordinate
   * @param {number} longitude - Longitude coordinate
   * @param {number} [radius=5000] - Search radius in meters
   * @returns {Promise<Array>} Array of nearby incidents
   */
  async getNearby(latitude, longitude, radius = 5000) {
    try {
      const response = await api.get('/incidents/nearby', {
        params: {
          lat: latitude,
          lng: longitude,
          radius: radius,
        },
      });
      return response.data.data;
    } catch (error) {
      console.error('Error fetching nearby incidents:', error.response?.data || error.message);
      throw error;
    }
  },

  /**
   * Verify/upvote an incident
   * @param {string} incidentId - The incident ID
   * @returns {Promise<Object>} The updated incident
   */
  async verify(incidentId) {
    try {
      const response = await api.post(`/incidents/${incidentId}/verify`);
      return response.data.data;
    } catch (error) {
      console.error('Error verifying incident:', error.response?.data || error.message);
      throw error;
    }
  },
};
