import { Socket } from 'phoenix';
import AsyncStorage from '@react-native-async-storage/async-storage';
import geohash from 'ngeohash';
import { API_URL } from './config';

class WebSocketService {
  constructor() {
    this.socket = null;
    this.incidentChannel = null;
    this.currentGeohash = null;
    this.onIncidentCallbacks = [];
  }

  /**
   * Connect to Phoenix WebSocket with JWT token
   */
  async connect() {
    try {
      // Get JWT token from storage
      const token = await AsyncStorage.getItem('auth_token');
      
      if (!token) {
        console.warn('No auth token found, cannot connect to WebSocket');
        return false;
      }

      // Create socket connection
      const wsUrl = API_URL.replace('http://', 'ws://').replace('https://', 'wss://');
      this.socket = new Socket(`${wsUrl}/socket`, {
        params: { token },
        reconnectAfterMs: (tries) => {
          // Exponential backoff: 1s, 2s, 5s, 10s, 10s...
          return [1000, 2000, 5000, 10000][tries - 1] || 10000;
        },
      });

      // Connect to socket
      this.socket.connect();

      // Handle connection events
      this.socket.onOpen(() => {
        console.log('WebSocket connected');
      });

      this.socket.onError((error) => {
        console.error('WebSocket error:', error);
      });

      this.socket.onClose(() => {
        console.log('WebSocket disconnected');
      });

      return true;
    } catch (error) {
      console.error('Failed to connect to WebSocket:', error);
      return false;
    }
  }

  /**
   * Join incident channel for a specific geohash
   */
  joinIncidentChannel(geohash) {
    if (!this.socket) {
      console.warn('Socket not connected');
      return;
    }

    // Leave previous channel if exists
    if (this.incidentChannel && this.currentGeohash !== geohash) {
      this.incidentChannel.leave();
    }

    // Join new channel
    this.currentGeohash = geohash;
    this.incidentChannel = this.socket.channel(`incidents:${geohash}`, {});

    // Handle channel events
    this.incidentChannel.on('incident:new', (incident) => {
      console.log('New incident received:', incident);
      this.notifyIncidentCallbacks(incident);
    });

    this.incidentChannel
      .join()
      .receive('ok', () => {
        console.log(`Joined incident channel for geohash: ${geohash}`);
      })
      .receive('error', (resp) => {
        console.error('Failed to join incident channel:', resp);
      });
  }

  /**
   * Update user location and rejoin channel if geohash changed
   */
  updateLocation(latitude, longitude) {
    if (!this.incidentChannel) {
      return;
    }

    // Send location update to server
    this.incidentChannel
      .push('location:update', { latitude, longitude })
      .receive('ok', (resp) => {
        const newGeohash = resp.geohash;
        
        // Rejoin channel if geohash changed
        if (newGeohash && newGeohash !== this.currentGeohash) {
          console.log(`Geohash changed from ${this.currentGeohash} to ${newGeohash}`);
          this.joinIncidentChannel(newGeohash);
        }
      })
      .receive('error', (resp) => {
        console.error('Failed to update location:', resp);
      });
  }

  /**
   * Subscribe to new incident events
   */
  onNewIncident(callback) {
    this.onIncidentCallbacks.push(callback);
    
    // Return unsubscribe function
    return () => {
      this.onIncidentCallbacks = this.onIncidentCallbacks.filter(cb => cb !== callback);
    };
  }

  /**
   * Notify all callbacks about new incident
   */
  notifyIncidentCallbacks(incident) {
    this.onIncidentCallbacks.forEach(callback => {
      try {
        callback(incident);
      } catch (error) {
        console.error('Error in incident callback:', error);
      }
    });
  }

  /**
   * Disconnect from WebSocket
   */
  disconnect() {
    if (this.incidentChannel) {
      this.incidentChannel.leave();
      this.incidentChannel = null;
    }

    if (this.socket) {
      this.socket.disconnect();
      this.socket = null;
    }

    this.currentGeohash = null;
    this.onIncidentCallbacks = [];
  }
}

// Export singleton instance
export default new WebSocketService();
