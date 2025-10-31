import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, Animated } from 'react-native';
import offlineService from '../services/offlineService';

const OfflineIndicator = () => {
  const [isOnline, setIsOnline] = useState(true);
  const [queueCount, setQueueCount] = useState(0);
  const slideAnim = useState(new Animated.Value(-100))[0];

  useEffect(() => {
    // Subscribe to connectivity changes
    const unsubscribe = offlineService.onConnectivityChange(async (online) => {
      setIsOnline(online);
      
      if (!online) {
        // Show offline banner
        Animated.spring(slideAnim, {
          toValue: 0,
          useNativeDriver: true,
          tension: 50,
          friction: 7
        }).start();
      } else {
        // Hide offline banner
        Animated.timing(slideAnim, {
          toValue: -100,
          duration: 300,
          useNativeDriver: true
        }).start();
      }

      // Update queue count
      const count = await offlineService.getQueueCount();
      setQueueCount(count);
    });

    // Initial check
    offlineService.checkConnectivity();

    return unsubscribe;
  }, []);

  if (isOnline && queueCount === 0) {
    return null;
  }

  return (
    <Animated.View 
      style={[
        styles.container,
        { transform: [{ translateY: slideAnim }] }
      ]}
    >
      <View style={[styles.banner, isOnline ? styles.syncing : styles.offline]}>
        <Text style={styles.icon}>{isOnline ? '🔄' : '📡'}</Text>
        <View style={styles.textContainer}>
          <Text style={styles.title}>
            {isOnline ? 'Syncing...' : 'You are offline'}
          </Text>
          {queueCount > 0 && (
            <Text style={styles.subtitle}>
              {queueCount} report{queueCount > 1 ? 's' : ''} queued
            </Text>
          )}
        </View>
      </View>
    </Animated.View>
  );
};

const styles = StyleSheet.create({
  container: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    zIndex: 1000,
  },
  banner: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 12,
    paddingTop: 50, // Account for status bar
  },
  offline: {
    backgroundColor: '#EF4444',
  },
  syncing: {
    backgroundColor: '#F59E0B',
  },
  icon: {
    fontSize: 20,
    marginRight: 12,
  },
  textContainer: {
    flex: 1,
  },
  title: {
    color: '#FFFFFF',
    fontSize: 14,
    fontWeight: '600',
  },
  subtitle: {
    color: '#FFFFFF',
    fontSize: 12,
    marginTop: 2,
    opacity: 0.9,
  },
});

export default OfflineIndicator;
