import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, Animated, TouchableOpacity, Dimensions } from 'react-native';

const { width } = Dimensions.get('window');

const NotificationBanner = ({ notification, onPress, onDismiss, duration = 5000 }) => {
  const [slideAnim] = useState(new Animated.Value(-100));
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    if (notification) {
      setVisible(true);
      // Slide in
      Animated.spring(slideAnim, {
        toValue: 0,
        useNativeDriver: true,
        tension: 50,
        friction: 8,
      }).start();

      // Auto dismiss after duration
      const timer = setTimeout(() => {
        handleDismiss();
      }, duration);

      return () => clearTimeout(timer);
    }
  }, [notification]);

  const handleDismiss = () => {
    Animated.timing(slideAnim, {
      toValue: -100,
      duration: 300,
      useNativeDriver: true,
    }).start(() => {
      setVisible(false);
      if (onDismiss) {
        onDismiss();
      }
    });
  };

  const handlePress = () => {
    handleDismiss();
    if (onPress) {
      onPress(notification);
    }
  };

  if (!visible || !notification) {
    return null;
  }

  const { title, body, data } = notification.request?.content || notification;
  const incidentType = data?.incident_type || 'incident';

  // Get color based on incident type
  const getTypeColor = (type) => {
    switch (type) {
      case 'hijacking':
        return '#EF4444'; // red
      case 'mugging':
        return '#F97316'; // orange
      case 'accident':
        return '#3B82F6'; // blue
      default:
        return '#6B7280'; // gray
    }
  };

  return (
    <Animated.View
      style={[
        styles.container,
        {
          transform: [{ translateY: slideAnim }],
          borderLeftColor: getTypeColor(incidentType),
        },
      ]}
    >
      <TouchableOpacity
        style={styles.content}
        onPress={handlePress}
        activeOpacity={0.9}
      >
        <View style={styles.textContainer}>
          <Text style={styles.title} numberOfLines={1}>
            {title}
          </Text>
          <Text style={styles.body} numberOfLines={2}>
            {body}
          </Text>
          {data?.distance && (
            <Text style={styles.distance}>
              {data.distance} • {data.time || 'just now'}
            </Text>
          )}
        </View>
        <TouchableOpacity
          style={styles.closeButton}
          onPress={handleDismiss}
          hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}
        >
          <Text style={styles.closeText}>✕</Text>
        </TouchableOpacity>
      </TouchableOpacity>
    </Animated.View>
  );
};

const styles = StyleSheet.create({
  container: {
    position: 'absolute',
    top: 50,
    left: 16,
    right: 16,
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    borderLeftWidth: 4,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 4,
    },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 8,
    zIndex: 9999,
  },
  content: {
    flexDirection: 'row',
    padding: 16,
    alignItems: 'flex-start',
  },
  textContainer: {
    flex: 1,
    marginRight: 8,
  },
  title: {
    fontSize: 16,
    fontWeight: '700',
    color: '#1F2937',
    marginBottom: 4,
  },
  body: {
    fontSize: 14,
    color: '#4B5563',
    lineHeight: 20,
    marginBottom: 4,
  },
  distance: {
    fontSize: 12,
    color: '#9CA3AF',
    marginTop: 4,
  },
  closeButton: {
    padding: 4,
  },
  closeText: {
    fontSize: 20,
    color: '#9CA3AF',
    fontWeight: '300',
  },
});

export default NotificationBanner;
