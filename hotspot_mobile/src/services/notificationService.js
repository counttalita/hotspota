import * as Notifications from 'expo-notifications';
import * as Device from 'expo-device';
import { Platform } from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { API_URL } from './config';

// Configure notification behavior
Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowAlert: true,
    shouldPlaySound: true,
    shouldSetBadge: true,
  }),
});

class NotificationService {
  constructor() {
    this.notificationListener = null;
    this.responseListener = null;
  }

  /**
   * Request notification permissions from the user
   */
  async requestPermissions() {
    try {
      if (!Device.isDevice) {
        console.log('Must use physical device for push notifications');
        return false;
      }

      const { status: existingStatus } = await Notifications.getPermissionsAsync();
      let finalStatus = existingStatus;

      if (existingStatus !== 'granted') {
        const { status } = await Notifications.requestPermissionsAsync();
        finalStatus = status;
      }

      if (finalStatus !== 'granted') {
        console.log('Failed to get push notification permissions');
        return false;
      }

      return true;
    } catch (error) {
      console.error('Error requesting notification permissions:', error);
      return false;
    }
  }

  /**
   * Get the FCM/APNS token for this device
   */
  async getToken() {
    try {
      const token = await Notifications.getExpoPushTokenAsync({
        projectId: 'your-expo-project-id', // Replace with your Expo project ID
      });

      return token.data;
    } catch (error) {
      console.error('Error getting push token:', error);
      return null;
    }
  }

  /**
   * Register the device token with the backend
   */
  async registerToken() {
    try {
      const hasPermission = await this.requestPermissions();
      if (!hasPermission) {
        return { success: false, error: 'Permission denied' };
      }

      const token = await this.getToken();
      if (!token) {
        return { success: false, error: 'Failed to get token' };
      }

      // Get auth token
      const authToken = await AsyncStorage.getItem('authToken');
      if (!authToken) {
        return { success: false, error: 'Not authenticated' };
      }

      // Determine platform
      const platform = Platform.OS === 'ios' ? 'ios' : 'android';

      // Register with backend
      const response = await fetch(`${API_URL}/notifications/register-token`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${authToken}`,
        },
        body: JSON.stringify({
          token,
          platform,
        }),
      });

      const data = await response.json();

      if (response.ok) {
        // Store token locally
        await AsyncStorage.setItem('fcmToken', token);
        return { success: true, data };
      } else {
        return { success: false, error: data.error || 'Failed to register token' };
      }
    } catch (error) {
      console.error('Error registering token:', error);
      return { success: false, error: error.message };
    }
  }

  /**
   * Get notification preferences from backend
   */
  async getPreferences() {
    try {
      const authToken = await AsyncStorage.getItem('authToken');
      if (!authToken) {
        throw new Error('Not authenticated');
      }

      const response = await fetch(`${API_URL}/notifications/preferences`, {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${authToken}`,
        },
      });

      const data = await response.json();

      if (response.ok) {
        return { success: true, data: data.data };
      } else {
        return { success: false, error: data.error };
      }
    } catch (error) {
      console.error('Error getting preferences:', error);
      return { success: false, error: error.message };
    }
  }

  /**
   * Update notification preferences
   */
  async updatePreferences(preferences) {
    try {
      const authToken = await AsyncStorage.getItem('authToken');
      if (!authToken) {
        throw new Error('Not authenticated');
      }

      const response = await fetch(`${API_URL}/notifications/preferences`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${authToken}`,
        },
        body: JSON.stringify(preferences),
      });

      const data = await response.json();

      if (response.ok) {
        return { success: true, data: data.data };
      } else {
        return { success: false, error: data.error };
      }
    } catch (error) {
      console.error('Error updating preferences:', error);
      return { success: false, error: error.message };
    }
  }

  /**
   * Set up notification listeners
   */
  setupListeners(onNotificationReceived, onNotificationTapped) {
    // Listener for notifications received while app is foregrounded
    this.notificationListener = Notifications.addNotificationReceivedListener(notification => {
      console.log('Notification received:', notification);
      if (onNotificationReceived) {
        onNotificationReceived(notification);
      }
    });

    // Listener for when user taps on notification
    this.responseListener = Notifications.addNotificationResponseReceivedListener(response => {
      console.log('Notification tapped:', response);
      if (onNotificationTapped) {
        const data = response.notification.request.content.data;
        onNotificationTapped(data);
      }
    });
  }

  /**
   * Remove notification listeners
   */
  removeListeners() {
    if (this.notificationListener) {
      Notifications.removeNotificationSubscription(this.notificationListener);
    }
    if (this.responseListener) {
      Notifications.removeNotificationSubscription(this.responseListener);
    }
  }

  /**
   * Show local notification (for in-app notifications)
   */
  async showLocalNotification(title, body, data = {}) {
    try {
      await Notifications.scheduleNotificationAsync({
        content: {
          title,
          body,
          data,
          sound: true,
        },
        trigger: null, // Show immediately
      });
    } catch (error) {
      console.error('Error showing local notification:', error);
    }
  }

  /**
   * Clear all notifications
   */
  async clearAllNotifications() {
    try {
      await Notifications.dismissAllNotificationsAsync();
    } catch (error) {
      console.error('Error clearing notifications:', error);
    }
  }

  /**
   * Get notification badge count
   */
  async getBadgeCount() {
    try {
      return await Notifications.getBadgeCountAsync();
    } catch (error) {
      console.error('Error getting badge count:', error);
      return 0;
    }
  }

  /**
   * Set notification badge count
   */
  async setBadgeCount(count) {
    try {
      await Notifications.setBadgeCountAsync(count);
    } catch (error) {
      console.error('Error setting badge count:', error);
    }
  }
}

export default new NotificationService();
