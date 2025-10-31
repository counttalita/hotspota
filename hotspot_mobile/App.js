import React, { useEffect, useState, useRef } from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createStackNavigator } from '@react-navigation/stack';
import { StatusBar } from 'expo-status-bar';
import { ActivityIndicator, View, StyleSheet } from 'react-native';

import PhoneAuthScreen from './src/screens/PhoneAuthScreen';
import OTPVerificationScreen from './src/screens/OTPVerificationScreen';
import MainScreen from './src/screens/MainScreen';
import NotificationBanner from './src/components/NotificationBanner';
import ErrorBoundary from './src/components/ErrorBoundary';
import { authService } from './src/services/authService';
import notificationService from './src/services/notificationService';

const Stack = createStackNavigator();

export default function App() {
  const [isLoading, setIsLoading] = useState(true);
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [currentNotification, setCurrentNotification] = useState(null);
  const navigationRef = useRef();

  useEffect(() => {
    checkAuth();
    setupNotifications();

    return () => {
      notificationService.removeListeners();
    };
  }, []);

  const checkAuth = async () => {
    try {
      const authenticated = await authService.isAuthenticated();
      setIsAuthenticated(authenticated);

      // Register for notifications if authenticated
      if (authenticated) {
        await notificationService.registerToken();
      }
    } catch (error) {
      console.error('Auth check failed:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const setupNotifications = () => {
    // Handle notification received while app is open
    notificationService.setupListeners(
      (notification) => {
        // Show in-app banner
        setCurrentNotification(notification);
      },
      (data) => {
        // Handle notification tap - navigate to incident on map
        if (data.incident_id && navigationRef.current) {
          navigationRef.current.navigate('Main', {
            screen: 'Map',
            params: {
              incidentId: data.incident_id,
              latitude: parseFloat(data.latitude),
              longitude: parseFloat(data.longitude),
            },
          });
        }
      }
    );
  };

  const handleNotificationPress = (notification) => {
    const data = notification.request?.content?.data || notification.data;
    if (data?.incident_id && navigationRef.current) {
      navigationRef.current.navigate('Main', {
        screen: 'Map',
        params: {
          incidentId: data.incident_id,
          latitude: parseFloat(data.latitude),
          longitude: parseFloat(data.longitude),
        },
      });
    }
    setCurrentNotification(null);
  };

  const handleNotificationDismiss = () => {
    setCurrentNotification(null);
  };

  if (isLoading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color="#007AFF" />
      </View>
    );
  }

  return (
    <ErrorBoundary
      onReset={() => {
        // Reset app state on error recovery
        setIsLoading(true);
        checkAuth();
      }}
      showReportButton={true}
    >
      <StatusBar style="auto" />
      <NavigationContainer ref={navigationRef}>
        <Stack.Navigator
          initialRouteName={isAuthenticated ? 'Main' : 'PhoneAuth'}
          screenOptions={{
            headerShown: false,
          }}
        >
          <Stack.Screen name="PhoneAuth" component={PhoneAuthScreen} />
          <Stack.Screen name="OTPVerification" component={OTPVerificationScreen} />
          <Stack.Screen name="Main" component={MainScreen} />
        </Stack.Navigator>
      </NavigationContainer>
      <NotificationBanner
        notification={currentNotification}
        onPress={handleNotificationPress}
        onDismiss={handleNotificationDismiss}
      />
    </ErrorBoundary>
  );
}

const styles = StyleSheet.create({
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#fff',
  },
});
