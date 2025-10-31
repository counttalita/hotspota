import AsyncStorage from '@react-native-async-storage/async-storage';
import NetInfo from '@react-native-community/netinfo';
import { v4 as uuidv4 } from 'uuid';

const OFFLINE_QUEUE_KEY = '@hotspot_offline_queue';
const CACHED_INCIDENTS_KEY = '@hotspot_cached_incidents';
const CACHED_TILES_KEY = '@hotspot_cached_tiles';

class OfflineService {
  constructor() {
    this.isOnline = true;
    this.listeners = [];
    this.setupNetworkListener();
  }

  setupNetworkListener() {
    NetInfo.addEventListener(state => {
      const wasOffline = !this.isOnline;
      this.isOnline = state.isConnected && state.isInternetReachable;
      
      // Notify listeners of connectivity change
      this.listeners.forEach(listener => listener(this.isOnline));
      
      // If we just came back online, trigger sync
      if (wasOffline && this.isOnline) {
        this.syncQueuedReports();
      }
    });
  }

  /**
   * Subscribe to connectivity changes
   * @param {Function} callback - Called with boolean indicating online status
   * @returns {Function} Unsubscribe function
   */
  onConnectivityChange(callback) {
    this.listeners.push(callback);
    // Immediately call with current status
    callback(this.isOnline);
    
    return () => {
      this.listeners = this.listeners.filter(l => l !== callback);
    };
  }

  /**
   * Check if device is currently online
   * @returns {boolean}
   */
  async checkConnectivity() {
    const state = await NetInfo.fetch();
    this.isOnline = state.isConnected && state.isInternetReachable;
    return this.isOnline;
  }

  /**
   * Queue an incident report for later submission when online
   * @param {Object} report - Incident report data
   * @returns {Promise<string>} Client ID for tracking
   */
  async queueReport(report) {
    const clientId = uuidv4();
    const idempotencyKey = uuidv4();
    
    const queuedReport = {
      ...report,
      client_id: clientId,
      idempotency_key: idempotencyKey,
      queued_at: new Date().toISOString(),
      status: 'pending'
    };

    const queue = await this.getQueue();
    queue.push(queuedReport);
    await AsyncStorage.setItem(OFFLINE_QUEUE_KEY, JSON.stringify(queue));
    
    return clientId;
  }

  /**
   * Get all queued reports
   * @returns {Promise<Array>}
   */
  async getQueue() {
    try {
      const queueJson = await AsyncStorage.getItem(OFFLINE_QUEUE_KEY);
      return queueJson ? JSON.parse(queueJson) : [];
    } catch (error) {
      console.error('Error reading offline queue:', error);
      return [];
    }
  }

  /**
   * Get count of pending reports in queue
   * @returns {Promise<number>}
   */
  async getQueueCount() {
    const queue = await this.getQueue();
    return queue.filter(r => r.status === 'pending').length;
  }

  /**
   * Sync all queued reports to the server
   * @param {Function} apiClient - Function to make API call
   * @returns {Promise<Object>} Sync results
   */
  async syncQueuedReports(apiClient) {
    if (!this.isOnline) {
      return { synced: 0, failed: 0, message: 'Device is offline' };
    }

    const queue = await this.getQueue();
    const pendingReports = queue.filter(r => r.status === 'pending');
    
    if (pendingReports.length === 0) {
      return { synced: 0, failed: 0, message: 'No reports to sync' };
    }

    try {
      // Call sync API endpoint
      const response = await apiClient.post('/sync/reports', {
        reports: pendingReports.map(r => ({
          type: r.type,
          latitude: r.latitude,
          longitude: r.longitude,
          description: r.description,
          photo_url: r.photo_url,
          idempotency_key: r.idempotency_key,
          client_id: r.client_id,
          reported_at: r.reported_at || r.queued_at
        }))
      });

      const { synced, failed, results } = response.data;
      
      // Update queue with results
      const updatedQueue = queue.map(report => {
        const result = results.find(r => r.client_id === report.client_id);
        if (result) {
          return {
            ...report,
            status: result.status === 'success' ? 'synced' : 'failed',
            server_id: result.id,
            error: result.reason,
            synced_at: new Date().toISOString()
          };
        }
        return report;
      });

      // Remove successfully synced reports after 24 hours
      const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
      const cleanedQueue = updatedQueue.filter(r => 
        r.status !== 'synced' || r.synced_at > oneDayAgo
      );

      await AsyncStorage.setItem(OFFLINE_QUEUE_KEY, JSON.stringify(cleanedQueue));
      
      return { synced, failed, results };
    } catch (error) {
      console.error('Error syncing reports:', error);
      return { synced: 0, failed: pendingReports.length, error: error.message };
    }
  }

  /**
   * Clear all synced reports from queue
   * @returns {Promise<void>}
   */
  async clearSyncedReports() {
    const queue = await this.getQueue();
    const pendingQueue = queue.filter(r => r.status !== 'synced');
    await AsyncStorage.setItem(OFFLINE_QUEUE_KEY, JSON.stringify(pendingQueue));
  }

  /**
   * Cache incidents for offline viewing
   * @param {Array} incidents - Array of incident objects
   * @returns {Promise<void>}
   */
  async cacheIncidents(incidents) {
    try {
      const cached = {
        incidents,
        cached_at: new Date().toISOString()
      };
      await AsyncStorage.setItem(CACHED_INCIDENTS_KEY, JSON.stringify(cached));
    } catch (error) {
      console.error('Error caching incidents:', error);
    }
  }

  /**
   * Get cached incidents
   * @param {number} maxAgeHours - Maximum age of cache in hours (default: 24)
   * @returns {Promise<Array|null>}
   */
  async getCachedIncidents(maxAgeHours = 24) {
    try {
      const cachedJson = await AsyncStorage.getItem(CACHED_INCIDENTS_KEY);
      if (!cachedJson) return null;

      const cached = JSON.parse(cachedJson);
      const cacheAge = Date.now() - new Date(cached.cached_at).getTime();
      const maxAge = maxAgeHours * 60 * 60 * 1000;

      if (cacheAge > maxAge) {
        // Cache is too old
        return null;
      }

      return cached.incidents;
    } catch (error) {
      console.error('Error reading cached incidents:', error);
      return null;
    }
  }

  /**
   * Cache map tile URLs for offline viewing
   * @param {Array} tileUrls - Array of tile URLs
   * @returns {Promise<void>}
   */
  async cacheMapTiles(tileUrls) {
    try {
      const existing = await this.getCachedTiles();
      const combined = [...new Set([...existing, ...tileUrls])];
      
      // Limit cache size to 1000 tiles
      const limited = combined.slice(-1000);
      
      await AsyncStorage.setItem(CACHED_TILES_KEY, JSON.stringify(limited));
    } catch (error) {
      console.error('Error caching map tiles:', error);
    }
  }

  /**
   * Get cached map tile URLs
   * @returns {Promise<Array>}
   */
  async getCachedTiles() {
    try {
      const tilesJson = await AsyncStorage.getItem(CACHED_TILES_KEY);
      return tilesJson ? JSON.parse(tilesJson) : [];
    } catch (error) {
      console.error('Error reading cached tiles:', error);
      return [];
    }
  }

  /**
   * Clear all offline data
   * @returns {Promise<void>}
   */
  async clearAllCache() {
    try {
      await AsyncStorage.multiRemove([
        OFFLINE_QUEUE_KEY,
        CACHED_INCIDENTS_KEY,
        CACHED_TILES_KEY
      ]);
    } catch (error) {
      console.error('Error clearing cache:', error);
    }
  }

  /**
   * Get offline storage statistics
   * @returns {Promise<Object>}
   */
  async getStorageStats() {
    const queue = await this.getQueue();
    const incidents = await this.getCachedIncidents();
    const tiles = await this.getCachedTiles();

    return {
      queuedReports: queue.length,
      pendingReports: queue.filter(r => r.status === 'pending').length,
      cachedIncidents: incidents ? incidents.length : 0,
      cachedTiles: tiles.length,
      isOnline: this.isOnline
    };
  }
}

export default new OfflineService();
