import apiClient from './apiClient';

class TravelService {
  /**
   * Analyze route safety between origin and destination
   * @param {Object} origin - {latitude, longitude}
   * @param {Object} destination - {latitude, longitude}
   * @param {number} radius - Buffer radius in meters (default: 1000)
   */
  async analyzeRoute(origin, destination, radius = 1000) {
    try {
      const response = await apiClient.post('/travel/analyze-route', {
        origin: {
          latitude: origin.latitude,
          longitude: origin.longitude,
        },
        destination: {
          latitude: destination.latitude,
          longitude: destination.longitude,
        },
        radius,
      });
      return response.data.data;
    } catch (error) {
      console.error('Analyze route error:', error);
      
      // Check if it's a premium feature error
      if (error.response?.status === 403) {
        throw new Error('Travel Mode is a premium feature. Please upgrade your subscription.');
      }
      
      throw new Error(error.response?.data?.error || 'Failed to analyze route');
    }
  }
}

export const travelService = new TravelService();
