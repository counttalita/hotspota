import { Socket } from 'phoenix';
import AsyncStorage from '@react-native-async-storage/async-storage';
import geohash from 'ngeohash';
import { API_URL } from './config';

class WebSocketService {
  constructor() {
    this.socket = null;
    this.incidentChannel = null;
    this.geofenceChannel = null;
    this.currentGeohash = null;
    this.userId = null;
    this.onIncidentCallbacks = [];
    this.onZoneEnteredCallbacks = [];
    this.onZoneExitedCallbacks = [];
    this.onZoneApproachingCallbacks = [];
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
   * Join geofence channel for zone entry/exit detection
   */
  async joinGeofenceChannel() {
    if (!this.socket) {
      console.warn('Socket not connected');
      return;
    }

    // Get user ID from storage
    const userDataStr = await AsyncStorage.getItem('user_data');
    if (!userDataStr) {
      console.warn('No user data found');
      return;
    }

    const userData = JSON.parse(userDataStr);
    this.userId = userData.id;

    // Join geofence channel
    this.geofenceChannel = this.socket.channel(`geofence:user:${this.userId}`, {});

    // Handle zone entry events
    this.geofenceChannel.on('zone:entered', (data) => {
      console.log('Entered hotspot zone:', data);
      this.notifyZoneEnteredCallbacks(data);
    });

    // Handle zone exit events
    this.geofenceChannel.on('zone:exited', (data) => {
      console.log('Exited hotspot zone:', data);
      this.notifyZoneExitedCallbacks(data);
    });

    // Handle zone approaching events (premium users)
    this.geofenceChannel.on('zone:approaching', (data) => {
      console.log('Approaching hotspot zone:', data);
      this.notifyZoneApproachingCallbacks(data);
    });

    this.geofenceChannel
      .join()
      .receive('ok', () => {
        console.log('Joined geofence channel');
      })
      .receive('error', (resp) => {
        console.error('Failed to join geofence channel:', resp);
      });
  }

  /**
   * Update location for geofence detection
   */
  updateGeofenceLocation(latitude, longitude) {
    if (!this.geofenceChannel) {
      return;
    }

    this.geofenceChannel
      .push('location:update', { latitude, longitude })
      .receive('ok', (resp) => {
        console.log('Geofence location updated:', resp);
      })
      .receive('error', (resp) => {
        console.error('Failed to update geofence location:', resp);
      });
  }

  /**
   * Subscribe to zone entered events
   */
  onZoneEntered(callback) {
    this.onZoneEnteredCallbacks.push(callback);
    
    return () => {
      this.onZoneEnteredCallbacks = this.onZoneEnteredCallbacks.filter(cb => cb !== callback);
    };
  }

  /**
   * Subscribe to zone exited events
   */
  onZoneExited(callback) {
    this.onZoneExitedCallbacks.push(callback);
    
    return () => {
      this.onZoneExitedCallbacks = this.onZoneExitedCallbacks.filter(cb => cb !== callback);
    };
  }

  /**
   * Subscribe to zone approaching events
   */
  onZoneApproaching(callback) {
    this.onZoneApproachingCallbacks.push(callback);
    
    return () => {
      this.onZoneApproachingCallbacks = this.onZoneApproachingCallbacks.filter(cb => cb !== callback);
    };
  }

  /**
   * Notify callbacks about zone entry
   */
  notifyZoneEnteredCallbacks(data) {
    this.onZoneEnteredCallbacks.forEach(callback => {
      try {
        callback(data);
      } catch (error) {
        console.error('Error in zone entered callback:', error);
      }
    });
  }

  /**
   * Notify callbacks about zone exit
   */
  notifyZoneExitedCallbacks(data) {
    this.onZoneExitedCallbacks.forEach(callback => {
      try {
        callback(data);
      } catch (error) {
        console.error('Error in zone exited callback:', error);
      }
    });
  }

  /**
   * Notify callbacks about zone approaching
   */
  notifyZoneApproachingCallbacks(data) {
    this.onZoneApproachingCallbacks.forEach(callback => {
      try {
        callback(data);
      } catch (error) {
        console.error('Error in zone approaching callback:', error);
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

    if (this.geofenceChannel) {
      this.geofenceChannel.leave();
      this.geofenceChannel = null;
    }

    if (this.socket) {
      this.socket.disconnect();
      this.socket = null;
    }

    this.currentGeohash = null;
    this.userId = null;
    this.onIncidentCallbacks = [];
    this.onZoneEnteredCallbacks = [];
    this.onZoneExitedCallbacks = [];
    this.onZoneApproachingCallbacks = [];
  }
}

// Export singleton instance
export default new WebSocketService();
