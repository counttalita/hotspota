import React, { useState, useEffect, useCallback } from 'react';
import {
  View,
  Text,
  FlatList,
  TouchableOpacity,
  RefreshControl,
  StyleSheet,
  ActivityIndicator,
  Alert,
} from 'react-native';
import * as Location from 'expo-location';
import { incidentService } from '../services/incidentService';

const IncidentFeedScreen = ({ navigation }) => {
  const [incidents, setIncidents] = useState([]);
  const [userLocation, setUserLocation] = useState(null);
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  
  // Filter states
  const [selectedType, setSelectedType] = useState('all');
  const [selectedTimeRange, setSelectedTimeRange] = useState('all');
  
  // Pagination states
  const [currentPage, setCurrentPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [totalCount, setTotalCount] = useState(0);

  // Get user location
  useEffect(() => {
    getUserLocation();
    
    // Set up location tracking to update distances
    const locationInterval = setInterval(() => {
      updateUserLocation();
    }, 30000); // Update every 30 seconds

    return () => clearInterval(locationInterval);
  }, []);

  // Fetch incidents when location or filters change
  useEffect(() => {
    if (userLocation) {
      fetchIncidents();
    }
  }, [userLocation, selectedType, selectedTimeRange]);

  const getUserLocation = async () => {
    try {
      const { status } = await Location.requestForegroundPermissionsAsync();
      if (status !== 'granted') {
        Alert.alert('Permission Denied', 'Location permission is required to view nearby incidents.');
        return;
      }

      const location = await Location.getCurrentPositionAsync({});
      setUserLocation({
        latitude: location.coords.latitude,
        longitude: location.coords.longitude,
      });
    } catch (error) {
      console.error('Error getting location:', error);
      Alert.alert('Error', 'Failed to get your location. Please try again.');
    }
  };

  const updateUserLocation = async () => {
    try {
      const location = await Location.getCurrentPositionAsync({});
      const newLocation = {
        latitude: location.coords.latitude,
        longitude: location.coords.longitude,
      };

      // Check if location changed significantly (more than 500 meters)
      if (userLocation) {
        const distance = calculateDistance(
          userLocation.latitude,
          userLocation.longitude,
          newLocation.latitude,
          newLocation.longitude
        );

        if (distance > 500) {
          setUserLocation(newLocation);
        }
      }
    } catch (error) {
      console.error('Error updating location:', error);
    }
  };

  const calculateDistance = (lat1, lon1, lat2, lon2) => {
    const R = 6371000; // Earth's radius in meters
    const φ1 = (lat1 * Math.PI) / 180;
    const φ2 = (lat2 * Math.PI) / 180;
    const Δφ = ((lat2 - lat1) * Math.PI) / 180;
    const Δλ = ((lon2 - lon1) * Math.PI) / 180;

    const a =
      Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
      Math.cos(φ1) * Math.cos(φ2) * Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

    return R * c;
  };

  const fetchIncidents = async (page = 1, append = false) => {
    if (!userLocation) return;

    try {
      if (!append) {
        setLoading(true);
      }

      const response = await incidentService.getFeed(
        userLocation.latitude,
        userLocation.longitude,
        {
          type: selectedType,
          timeRange: selectedTimeRange,
          page: page,
          pageSize: 20,
        }
      );

      if (append) {
        setIncidents([...incidents, ...response.incidents]);
      } else {
        setIncidents(response.incidents);
      }

      setCurrentPage(response.pagination.page);
      setTotalPages(response.pagination.total_pages);
      setTotalCount(response.pagination.total_count);
    } catch (error) {
      console.error('Error fetching incidents:', error);
      Alert.alert('Error', 'Failed to load incidents. Please try again.');
    } finally {
      setLoading(false);
      setRefreshing(false);
      setLoadingMore(false);
    }
  };

  const onRefresh = useCallback(() => {
    setRefreshing(true);
    setCurrentPage(1);
    fetchIncidents(1, false);
  }, [userLocation, selectedType, selectedTimeRange]);

  const loadMore = () => {
    if (currentPage < totalPages && !loadingMore) {
      setLoadingMore(true);
      fetchIncidents(currentPage + 1, true);
    }
  };

  const getIncidentIcon = (type) => {
    switch (type) {
      case 'hijacking':
        return '🚗';
      case 'mugging':
        return '👤';
      case 'accident':
        return '🚑';
      default:
        return '⚠️';
    }
  };

  const getTimeAgo = (timestamp) => {
    const now = new Date();
    const incidentTime = new Date(timestamp);
    const diffMs = now - incidentTime;
    const diffMins = Math.floor(diffMs / 60000);
    const diffHours = Math.floor(diffMins / 60);
    const diffDays = Math.floor(diffHours / 24);

    if (diffMins < 1) return 'Just now';
    if (diffMins < 60) return `${diffMins}m ago`;
    if (diffHours < 24) return `${diffHours}h ago`;
    return `${diffDays}d ago`;
  };

  const formatDistance = (meters) => {
    if (meters < 1000) {
      return `${Math.round(meters)}m`;
    }
    return `${(meters / 1000).toFixed(1)}km`;
  };

  const renderIncidentItem = ({ item }) => (
    <TouchableOpacity
      style={styles.incidentCard}
      onPress={() => navigation.navigate('Map', { focusIncident: item.id })}
    >
      <View style={styles.incidentHeader}>
        <Text style={styles.incidentIcon}>{getIncidentIcon(item.type)}</Text>
        <View style={styles.incidentInfo}>
          <Text style={styles.incidentType}>
            {item.type.charAt(0).toUpperCase() + item.type.slice(1)}
          </Text>
          <Text style={styles.incidentMeta}>
            {item.distance ? formatDistance(item.distance) : 'Unknown'} • {getTimeAgo(item.inserted_at)}
          </Text>
        </View>
        {item.is_verified && (
          <View style={styles.verifiedBadge}>
            <Text style={styles.verifiedText}>✓ Verified</Text>
          </View>
        )}
      </View>
      {item.description && (
        <Text style={styles.incidentDescription} numberOfLines={2}>
          {item.description}
        </Text>
      )}
      <View style={styles.incidentFooter}>
        <Text style={styles.verificationCount}>
          {item.verification_count} {item.verification_count === 1 ? 'verification' : 'verifications'}
        </Text>
      </View>
    </TouchableOpacity>
  );

  const renderFilterButton = (label, value, currentValue, onPress) => (
    <TouchableOpacity
      style={[
        styles.filterButton,
        currentValue === value && styles.filterButtonActive,
      ]}
      onPress={() => onPress(value)}
    >
      <Text
        style={[
          styles.filterButtonText,
          currentValue === value && styles.filterButtonTextActive,
        ]}
      >
        {label}
      </Text>
    </TouchableOpacity>
  );

  const renderHeader = () => (
    <View style={styles.header}>
      <Text style={styles.headerTitle}>Incident Feed</Text>
      <Text style={styles.headerSubtitle}>
        {totalCount} {totalCount === 1 ? 'incident' : 'incidents'} nearby
      </Text>

      {/* Type Filter */}
      <View style={styles.filterSection}>
        <Text style={styles.filterLabel}>Type</Text>
        <View style={styles.filterButtons}>
          {renderFilterButton('All', 'all', selectedType, setSelectedType)}
          {renderFilterButton('Hijacking', 'hijacking', selectedType, setSelectedType)}
          {renderFilterButton('Mugging', 'mugging', selectedType, setSelectedType)}
          {renderFilterButton('Accident', 'accident', selectedType, setSelectedType)}
        </View>
      </View>

      {/* Time Range Filter */}
      <View style={styles.filterSection}>
        <Text style={styles.filterLabel}>Time Range</Text>
        <View style={styles.filterButtons}>
          {renderFilterButton('All', 'all', selectedTimeRange, setSelectedTimeRange)}
          {renderFilterButton('Last 24h', '24h', selectedTimeRange, setSelectedTimeRange)}
          {renderFilterButton('Last 7 days', '7d', selectedTimeRange, setSelectedTimeRange)}
        </View>
      </View>
    </View>
  );

  const renderFooter = () => {
    if (!loadingMore) return null;
    return (
      <View style={styles.footerLoader}>
        <ActivityIndicator size="small" color="#007AFF" />
      </View>
    );
  };

  const renderEmpty = () => (
    <View style={styles.emptyContainer}>
      <Text style={styles.emptyIcon}>📍</Text>
      <Text style={styles.emptyText}>No incidents found</Text>
      <Text style={styles.emptySubtext}>
        Try adjusting your filters or check back later
      </Text>
    </View>
  );

  if (loading && incidents.length === 0) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color="#007AFF" />
        <Text style={styles.loadingText}>Loading incidents...</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <FlatList
        data={incidents}
        renderItem={renderIncidentItem}
        keyExtractor={(item) => item.id}
        ListHeaderComponent={renderHeader}
        ListEmptyComponent={renderEmpty}
        ListFooterComponent={renderFooter}
        refreshControl={
          <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
        }
        onEndReached={loadMore}
        onEndReachedThreshold={0.5}
        contentContainerStyle={styles.listContent}
      />
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F5F5F5',
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#F5F5F5',
  },
  loadingText: {
    marginTop: 12,
    fontSize: 16,
    color: '#666',
  },
  listContent: {
    flexGrow: 1,
  },
  header: {
    backgroundColor: '#FFF',
    padding: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#E0E0E0',
  },
  headerTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 4,
  },
  headerSubtitle: {
    fontSize: 14,
    color: '#666',
    marginBottom: 16,
  },
  filterSection: {
    marginTop: 12,
  },
  filterLabel: {
    fontSize: 14,
    fontWeight: '600',
    color: '#333',
    marginBottom: 8,
  },
  filterButtons: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  filterButton: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 20,
    backgroundColor: '#F0F0F0',
    borderWidth: 1,
    borderColor: '#E0E0E0',
  },
  filterButtonActive: {
    backgroundColor: '#007AFF',
    borderColor: '#007AFF',
  },
  filterButtonText: {
    fontSize: 14,
    color: '#666',
    fontWeight: '500',
  },
  filterButtonTextActive: {
    color: '#FFF',
  },
  incidentCard: {
    backgroundColor: '#FFF',
    marginHorizontal: 16,
    marginVertical: 8,
    padding: 16,
    borderRadius: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  incidentHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 8,
  },
  incidentIcon: {
    fontSize: 32,
    marginRight: 12,
  },
  incidentInfo: {
    flex: 1,
  },
  incidentType: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333',
    marginBottom: 2,
  },
  incidentMeta: {
    fontSize: 14,
    color: '#666',
  },
  verifiedBadge: {
    backgroundColor: '#4CAF50',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 12,
  },
  verifiedText: {
    fontSize: 12,
    color: '#FFF',
    fontWeight: '600',
  },
  incidentDescription: {
    fontSize: 14,
    color: '#666',
    marginBottom: 8,
    lineHeight: 20,
  },
  incidentFooter: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  verificationCount: {
    fontSize: 12,
    color: '#999',
  },
  footerLoader: {
    paddingVertical: 20,
    alignItems: 'center',
  },
  emptyContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingVertical: 60,
  },
  emptyIcon: {
    fontSize: 64,
    marginBottom: 16,
  },
  emptyText: {
    fontSize: 18,
    fontWeight: '600',
    color: '#333',
    marginBottom: 8,
  },
  emptySubtext: {
    fontSize: 14,
    color: '#666',
    textAlign: 'center',
  },
});

export default IncidentFeedScreen;
