import api from './config';

export const geofenceService = {
  /**
   * Get all active hotspot zones
   */
  async getZones() {
    try {
      const response = await api.get('/geofence/zones');
      return response.data.data;
    } catch (error) {
      console.error('Error fetching zones:', error);
      throw error;
    }
  },

  /**
   * Get a specific zone by ID
   */
  async getZone(zoneId) {
    try {
      const response = await api.get(`/geofence/zones/${zoneId}`);
      return response.data.data;
    } catch (error) {
      console.error('Error fetching zone:', error);
      throw error;
    }
  },

  /**
   * Check if a location is within any hotspot zones
   */
  async checkLocation(latitude, longitude) {
    try {
      const response = await api.post('/geofence/check-location', {
        latitude,
        longitude,
      });
      return response.data.data;
    } catch (error) {
      console.error('Error checking location:', error);
      throw error;
    }
  },

  /**
   * Get zones that the user is currently in
   */
  async getUserZones() {
    try {
      const response = await api.get('/geofence/user-zones');
      return response.data.data;
    } catch (error) {
      console.error('Error fetching user zones:', error);
      throw error;
    }
  },
};

export default geofenceService;
