import apiClient from './apiClient';

class TravelService {
  /**
   * Analyze route safety between origin and destination with segment breakdown
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

  /**
   * Get alternative safer routes
   * @param {Object} origin - {latitude, longitude}
   * @param {Object} destination - {latitude, longitude}
   * @param {number} radius - Buffer radius in meters (default: 1000)
   */
  async getAlternativeRoutes(origin, destination, radius = 1000) {
    try {
      const response = await apiClient.post('/travel/alternative-routes', {
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
      console.error('Get alternative routes error:', error);
      
      if (error.response?.status === 403) {
        throw new Error('Alternative routes is a premium feature. Please upgrade your subscription.');
      }
      
      throw new Error(error.response?.data?.error || 'Failed to get alternative routes');
    }
  }

  /**
   * Get real-time route risk updates during active journey
   * @param {Object} currentLocation - {latitude, longitude}
   * @param {Object} destination - {latitude, longitude}
   * @param {number} radius - Buffer radius in meters (default: 1000)
   */
  async getRealtimeUpdates(currentLocation, destination, radius = 1000) {
    try {
      const response = await apiClient.post('/travel/realtime-updates', {
        current_location: {
          latitude: currentLocation.latitude,
          longitude: currentLocation.longitude,
        },
        destination: {
          latitude: destination.latitude,
          longitude: destination.longitude,
        },
        radius,
      });
      return response.data.data;
    } catch (error) {
      console.error('Get realtime updates error:', error);
      
      if (error.response?.status === 403) {
        throw new Error('Real-time updates is a premium feature. Please upgrade your subscription.');
      }
      
      throw new Error(error.response?.data?.error || 'Failed to get realtime updates');
    }
  }
}

export const travelService = new TravelService();
