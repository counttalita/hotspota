import axios from 'axios';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { API_URL } from './config';
import offlineService from './offlineService';

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
   * Upload a photo to Appwrite storage
   * @param {Object} photo - The photo object from image picker
   * @param {string} photo.uri - Local URI of the photo
   * @param {string} photo.type - MIME type of the photo
   * @param {string} photo.fileName - Name of the file
   * @returns {Promise<Object>} Object containing file_id and photo_url
   */
  async uploadPhoto(photo) {
    try {
      const formData = new FormData();
      formData.append('photo', {
        uri: photo.uri,
        type: photo.type || 'image/jpeg',
        name: photo.fileName || 'incident_photo.jpg',
      });

      const response = await api.post('/incidents/upload-photo', formData, {
        headers: {
          'Content-Type': 'multipart/form-data',
        },
      });
      return response.data;
    } catch (error) {
      console.error('Error uploading photo:', error.response?.data || error.message);
      throw error;
    }
  },

  /**
   * Create a new incident report
   * @param {Object} incidentData - The incident data
   * @param {string} incidentData.type - Type of incident (hijacking, mugging, accident)
   * @param {number} incidentData.latitude - Latitude coordinate
   * @param {number} incidentData.longitude - Longitude coordinate
   * @param {string} [incidentData.description] - Optional description
   * @param {string} [incidentData.photo_url] - Optional photo URL
   * @returns {Promise<Object>} The created incident or queued report
   */
  async create(incidentData) {
    // Check if online
    const isOnline = await offlineService.checkConnectivity();
    
    if (!isOnline) {
      // Queue for later submission
      const clientId = await offlineService.queueReport(incidentData);
      return {
        ...incidentData,
        id: clientId,
        queued: true,
        status: 'pending_sync'
      };
    }

    try {
      const response = await api.post('/incidents', {
        incident: incidentData,
      });
      return response.data.data;
    } catch (error) {
      // If network error, queue the report
      if (error.code === 'ECONNABORTED' || error.code === 'ERR_NETWORK' || !error.response) {
        const clientId = await offlineService.queueReport(incidentData);
        return {
          ...incidentData,
          id: clientId,
          queued: true,
          status: 'pending_sync'
        };
      }
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
      
      // Cache incidents for offline viewing
      await offlineService.cacheIncidents(response.data.data);
      
      return response.data.data;
    } catch (error) {
      console.error('Error fetching nearby incidents:', error.response?.data || error.message);
      
      // Try to return cached incidents if offline
      const cached = await offlineService.getCachedIncidents();
      if (cached) {
        console.log('Returning cached incidents (offline mode)');
        return cached.map(incident => ({ ...incident, cached: true }));
      }
      
      throw error;
    }
  },

  /**
   * Get paginated incident feed with filtering
   * @param {number} latitude - Latitude coordinate
   * @param {number} longitude - Longitude coordinate
   * @param {Object} options - Filter and pagination options
   * @param {number} [options.radius=5000] - Search radius in meters
   * @param {string} [options.type] - Filter by incident type (hijacking, mugging, accident, all)
   * @param {string} [options.timeRange='all'] - Filter by time range (24h, 7d, all)
   * @param {number} [options.page=1] - Page number
   * @param {number} [options.pageSize=20] - Items per page
   * @returns {Promise<Object>} Object containing incidents array and pagination info
   */
  async getFeed(latitude, longitude, options = {}) {
    try {
      const {
        radius = 5000,
        type = 'all',
        timeRange = 'all',
        page = 1,
        pageSize = 20,
      } = options;

      const response = await api.get('/incidents/feed', {
        params: {
          lat: latitude,
          lng: longitude,
          radius: radius,
          type: type !== 'all' ? type : undefined,
          time_range: timeRange,
          page: page,
          page_size: pageSize,
        },
      });
      return response.data;
    } catch (error) {
      console.error('Error fetching incident feed:', error.response?.data || error.message);
      throw error;
    }
  },

  /**
   * Verify/upvote an incident
   * @param {string} incidentId - The incident ID
   * @returns {Promise<Object>} The verification result with updated counts
   */
  async verify(incidentId) {
    try {
      const response = await api.post(`/incidents/${incidentId}/verify`);
      return response.data;
    } catch (error) {
      console.error('Error verifying incident:', error.response?.data || error.message);
      throw error;
    }
  },

  /**
   * Get verifications for an incident
   * @param {string} incidentId - The incident ID
   * @returns {Promise<Object>} Object containing verification count and list
   */
  async getVerifications(incidentId) {
    try {
      const response = await api.get(`/incidents/${incidentId}/verifications`);
      return response.data;
    } catch (error) {
      console.error('Error fetching verifications:', error.response?.data || error.message);
      throw error;
    }
  },

  /**
   * Sync all queued offline reports to the server
   * @returns {Promise<Object>} Object with synced and failed counts
   */
  async syncOfflineReports() {
    try {
      const result = await offlineService.syncQueuedReports(api);
      return result;
    } catch (error) {
      console.error('Error syncing offline reports:', error);
      throw error;
    }
  },

  /**
   * Get count of queued offline reports
   * @returns {Promise<number>}
   */
  async getOfflineQueueCount() {
    return await offlineService.getQueueCount();
  },

  /**
   * Get heatmap data showing incident clusters from the past 7 days
   * @returns {Promise<Object>} Object containing clusters array and generated_at timestamp
   */
  async getHeatmap() {
    try {
      const response = await api.get('/incidents/heatmap');
      return response.data;
    } catch (error) {
      console.error('Error fetching heatmap data:', error.response?.data || error.message);
      throw error;
    }
  },
};
