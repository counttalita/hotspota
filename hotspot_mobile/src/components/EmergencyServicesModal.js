import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  Modal,
  TouchableOpacity,
  FlatList,
  StyleSheet,
  ActivityIndicator,
  Linking,
  Platform,
  Alert,
} from 'react-native';
import { findNearbyEmergencyServices } from '../services/emergencyService';

const EmergencyServicesModal = ({ visible, onClose, latitude, longitude }) => {
  const [loading, setLoading] = useState(false);
  const [services, setServices] = useState({ police_stations: [], hospitals: [] });
  const [selectedTab, setSelectedTab] = useState('police'); // 'police' or 'hospitals'
  const [error, setError] = useState(null);

  useEffect(() => {
    if (visible && latitude && longitude) {
      loadEmergencyServices();
    }
  }, [visible, latitude, longitude]);

  const loadEmergencyServices = async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await findNearbyEmergencyServices(latitude, longitude, 5000);
      setServices(data);
    } catch (err) {
      console.error('Error loading emergency services:', err);
      setError('Failed to load emergency services. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const openDirections = (service) => {
    const { latitude: lat, longitude: lng } = service.location;
    const label = encodeURIComponent(service.name);
    
    const scheme = Platform.select({
      ios: 'maps:0,0?q=',
      android: 'geo:0,0?q=',
    });
    const latLng = `${lat},${lng}`;
    const url = Platform.select({
      ios: `${scheme}${label}@${latLng}`,
      android: `${scheme}${latLng}(${label})`,
    });

    Linking.canOpenURL(url)
      .then((supported) => {
        if (supported) {
          return Linking.openURL(url);
        } else {
          // Fallback to Google Maps web
          const googleMapsUrl = `https://www.google.com/maps/dir/?api=1&destination=${latLng}`;
          return Linking.openURL(googleMapsUrl);
        }
      })
      .catch((err) => {
        console.error('Error opening maps:', err);
        Alert.alert('Error', 'Could not open maps application');
      });
  };

  const renderServiceItem = ({ item }) => (
    <View style={styles.serviceItem}>
      <View style={styles.serviceInfo}>
        <Text style={styles.serviceName}>{item.name}</Text>
        <Text style={styles.serviceAddress}>{item.address}</Text>
        <View style={styles.serviceDetails}>
          <Text style={styles.serviceDistance}>{item.distance_text}</Text>
          <Text style={styles.serviceDuration}>• {item.duration_text}</Text>
          {item.rating && (
            <Text style={styles.serviceRating}>• ⭐ {item.rating.toFixed(1)}</Text>
          )}
        </View>
        {item.open_now !== undefined && (
          <Text style={[styles.serviceStatus, item.open_now ? styles.open : styles.closed]}>
            {item.open_now ? '🟢 Open now' : '🔴 Closed'}
          </Text>
        )}
      </View>
      <TouchableOpacity
        style={styles.directionsButton}
        onPress={() => openDirections(item)}
      >
        <Text style={styles.directionsButtonText}>Directions</Text>
      </TouchableOpacity>
    </View>
  );

  const currentServices = selectedTab === 'police' ? services.police_stations : services.hospitals;

  return (
    <Modal
      visible={visible}
      animationType="slide"
      transparent={true}
      onRequestClose={onClose}
    >
      <View style={styles.modalOverlay}>
        <View style={styles.modalContent}>
          <View style={styles.header}>
            <Text style={styles.title}>Find Help Nearby</Text>
            <TouchableOpacity onPress={onClose} style={styles.closeButton}>
              <Text style={styles.closeButtonText}>✕</Text>
            </TouchableOpacity>
          </View>

          <View style={styles.tabs}>
            <TouchableOpacity
              style={[styles.tab, selectedTab === 'police' && styles.activeTab]}
              onPress={() => setSelectedTab('police')}
            >
              <Text style={[styles.tabText, selectedTab === 'police' && styles.activeTabText]}>
                🚔 Police Stations
              </Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[styles.tab, selectedTab === 'hospitals' && styles.activeTab]}
              onPress={() => setSelectedTab('hospitals')}
            >
              <Text style={[styles.tabText, selectedTab === 'hospitals' && styles.activeTabText]}>
                🏥 Hospitals
              </Text>
            </TouchableOpacity>
          </View>

          {loading ? (
            <View style={styles.loadingContainer}>
              <ActivityIndicator size="large" color="#007AFF" />
              <Text style={styles.loadingText}>Finding nearby services...</Text>
            </View>
          ) : error ? (
            <View style={styles.errorContainer}>
              <Text style={styles.errorText}>{error}</Text>
              <TouchableOpacity style={styles.retryButton} onPress={loadEmergencyServices}>
                <Text style={styles.retryButtonText}>Retry</Text>
              </TouchableOpacity>
            </View>
          ) : currentServices.length === 0 ? (
            <View style={styles.emptyContainer}>
              <Text style={styles.emptyText}>
                No {selectedTab === 'police' ? 'police stations' : 'hospitals'} found nearby
              </Text>
            </View>
          ) : (
            <FlatList
              data={currentServices}
              renderItem={renderServiceItem}
              keyExtractor={(item) => item.place_id}
              contentContainerStyle={styles.listContent}
            />
          )}
        </View>
      </View>
    </Modal>
  );
};

const styles = StyleSheet.create({
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'flex-end',
  },
  modalContent: {
    backgroundColor: '#fff',
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    maxHeight: '80%',
    paddingBottom: 20,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 20,
    borderBottomWidth: 1,
    borderBottomColor: '#e0e0e0',
  },
  title: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#333',
  },
  closeButton: {
    padding: 5,
  },
  closeButtonText: {
    fontSize: 24,
    color: '#666',
  },
  tabs: {
    flexDirection: 'row',
    borderBottomWidth: 1,
    borderBottomColor: '#e0e0e0',
  },
  tab: {
    flex: 1,
    paddingVertical: 15,
    alignItems: 'center',
  },
  activeTab: {
    borderBottomWidth: 2,
    borderBottomColor: '#007AFF',
  },
  tabText: {
    fontSize: 14,
    color: '#666',
  },
  activeTabText: {
    color: '#007AFF',
    fontWeight: '600',
  },
  loadingContainer: {
    padding: 40,
    alignItems: 'center',
  },
  loadingText: {
    marginTop: 10,
    color: '#666',
  },
  errorContainer: {
    padding: 40,
    alignItems: 'center',
  },
  errorText: {
    color: '#d32f2f',
    textAlign: 'center',
    marginBottom: 15,
  },
  retryButton: {
    backgroundColor: '#007AFF',
    paddingHorizontal: 20,
    paddingVertical: 10,
    borderRadius: 8,
  },
  retryButtonText: {
    color: '#fff',
    fontWeight: '600',
  },
  emptyContainer: {
    padding: 40,
    alignItems: 'center',
  },
  emptyText: {
    color: '#666',
    textAlign: 'center',
  },
  listContent: {
    padding: 15,
  },
  serviceItem: {
    backgroundColor: '#f9f9f9',
    borderRadius: 12,
    padding: 15,
    marginBottom: 12,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  serviceInfo: {
    flex: 1,
    marginRight: 10,
  },
  serviceName: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333',
    marginBottom: 4,
  },
  serviceAddress: {
    fontSize: 13,
    color: '#666',
    marginBottom: 6,
  },
  serviceDetails: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 4,
  },
  serviceDistance: {
    fontSize: 12,
    color: '#007AFF',
    fontWeight: '500',
  },
  serviceDuration: {
    fontSize: 12,
    color: '#666',
    marginLeft: 4,
  },
  serviceRating: {
    fontSize: 12,
    color: '#666',
    marginLeft: 4,
  },
  serviceStatus: {
    fontSize: 12,
    fontWeight: '500',
  },
  open: {
    color: '#4caf50',
  },
  closed: {
    color: '#f44336',
  },
  directionsButton: {
    backgroundColor: '#007AFF',
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderRadius: 8,
  },
  directionsButtonText: {
    color: '#fff',
    fontWeight: '600',
    fontSize: 13,
  },
});

export default EmergencyServicesModal;
