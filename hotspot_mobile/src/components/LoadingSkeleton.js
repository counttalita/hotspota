import React, { useEffect, useRef } from 'react';
import { View, Animated, StyleSheet } from 'react-native';

/**
 * Loading skeleton components for better perceived performance.
 * Provides visual feedback while content is loading.
 */

export const SkeletonPlaceholder = ({ children, style }) => {
  const animatedValue = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    Animated.loop(
      Animated.sequence([
        Animated.timing(animatedValue, {
          toValue: 1,
          duration: 1000,
          useNativeDriver: true,
        }),
        Animated.timing(animatedValue, {
          toValue: 0,
          duration: 1000,
          useNativeDriver: true,
        }),
      ])
    ).start();
  }, []);

  const opacity = animatedValue.interpolate({
    inputRange: [0, 1],
    outputRange: [0.3, 0.7],
  });

  return (
    <Animated.View style={[styles.skeleton, style, { opacity }]}>
      {children}
    </Animated.View>
  );
};

export const IncidentFeedSkeleton = () => {
  return (
    <View style={styles.feedContainer}>
      {[1, 2, 3, 4, 5].map((key) => (
        <View key={key} style={styles.feedItem}>
          <SkeletonPlaceholder style={styles.feedIcon} />
          <View style={styles.feedContent}>
            <SkeletonPlaceholder style={styles.feedTitle} />
            <SkeletonPlaceholder style={styles.feedSubtitle} />
          </View>
          <SkeletonPlaceholder style={styles.feedBadge} />
        </View>
      ))}
    </View>
  );
};

export const MapMarkerSkeleton = () => {
  return (
    <View style={styles.mapContainer}>
      {[1, 2, 3, 4, 5, 6].map((key) => (
        <SkeletonPlaceholder
          key={key}
          style={[
            styles.mapMarker,
            {
              top: `${Math.random() * 80 + 10}%`,
              left: `${Math.random() * 80 + 10}%`,
            },
          ]}
        />
      ))}
    </View>
  );
};

export const AnalyticsCardSkeleton = () => {
  return (
    <View style={styles.analyticsContainer}>
      <View style={styles.analyticsCard}>
        <SkeletonPlaceholder style={styles.analyticsTitle} />
        <SkeletonPlaceholder style={styles.analyticsValue} />
      </View>
      <View style={styles.analyticsCard}>
        <SkeletonPlaceholder style={styles.analyticsTitle} />
        <SkeletonPlaceholder style={styles.analyticsValue} />
      </View>
      <View style={styles.analyticsCard}>
        <SkeletonPlaceholder style={styles.analyticsTitle} />
        <SkeletonPlaceholder style={styles.analyticsValue} />
      </View>
    </View>
  );
};

export const SettingsListSkeleton = () => {
  return (
    <View style={styles.settingsContainer}>
      {[1, 2, 3, 4, 5, 6].map((key) => (
        <View key={key} style={styles.settingsItem}>
          <SkeletonPlaceholder style={styles.settingsIcon} />
          <View style={styles.settingsContent}>
            <SkeletonPlaceholder style={styles.settingsTitle} />
            <SkeletonPlaceholder style={styles.settingsSubtitle} />
          </View>
          <SkeletonPlaceholder style={styles.settingsArrow} />
        </View>
      ))}
    </View>
  );
};

export const ImageSkeleton = ({ style }) => {
  return <SkeletonPlaceholder style={[styles.imageSkeleton, style]} />;
};

export const TextSkeleton = ({ width = '100%', height = 16, style }) => {
  return (
    <SkeletonPlaceholder
      style={[
        styles.textSkeleton,
        { width, height },
        style,
      ]}
    />
  );
};

export const CircleSkeleton = ({ size = 40, style }) => {
  return (
    <SkeletonPlaceholder
      style={[
        styles.circleSkeleton,
        { width: size, height: size, borderRadius: size / 2 },
        style,
      ]}
    />
  );
};

const styles = StyleSheet.create({
  skeleton: {
    backgroundColor: '#E1E9EE',
    overflow: 'hidden',
  },
  
  // Feed Skeleton
  feedContainer: {
    padding: 16,
  },
  feedItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#f0f0f0',
  },
  feedIcon: {
    width: 40,
    height: 40,
    borderRadius: 20,
    marginRight: 12,
  },
  feedContent: {
    flex: 1,
  },
  feedTitle: {
    height: 16,
    width: '70%',
    borderRadius: 4,
    marginBottom: 8,
  },
  feedSubtitle: {
    height: 12,
    width: '50%',
    borderRadius: 4,
  },
  feedBadge: {
    width: 60,
    height: 24,
    borderRadius: 12,
  },
  
  // Map Skeleton
  mapContainer: {
    flex: 1,
    position: 'relative',
  },
  mapMarker: {
    position: 'absolute',
    width: 36,
    height: 36,
    borderRadius: 18,
  },
  
  // Analytics Skeleton
  analyticsContainer: {
    padding: 16,
  },
  analyticsCard: {
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 16,
    marginBottom: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  analyticsTitle: {
    height: 14,
    width: '40%',
    borderRadius: 4,
    marginBottom: 12,
  },
  analyticsValue: {
    height: 32,
    width: '60%',
    borderRadius: 4,
  },
  
  // Settings Skeleton
  settingsContainer: {
    padding: 16,
  },
  settingsItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#f0f0f0',
  },
  settingsIcon: {
    width: 32,
    height: 32,
    borderRadius: 16,
    marginRight: 12,
  },
  settingsContent: {
    flex: 1,
  },
  settingsTitle: {
    height: 16,
    width: '60%',
    borderRadius: 4,
    marginBottom: 6,
  },
  settingsSubtitle: {
    height: 12,
    width: '40%',
    borderRadius: 4,
  },
  settingsArrow: {
    width: 20,
    height: 20,
    borderRadius: 4,
  },
  
  // Generic Skeletons
  imageSkeleton: {
    width: '100%',
    height: 200,
    borderRadius: 8,
  },
  textSkeleton: {
    borderRadius: 4,
  },
  circleSkeleton: {
    backgroundColor: '#E1E9EE',
  },
});
