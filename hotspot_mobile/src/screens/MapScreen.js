import React, { useState, useEffect, useRef, useMemo } from 'react';
import {
  View,
  StyleSheet,
  TouchableOpacity,
  Text,
  Alert,
  ActivityIndicator,
} from 'react-native';
import MapView, { Marker, Circle, PROVIDER_GOOGLE } from 'react-native-maps';
import * as Location from 'expo-location';
import NetInfo from '@react-native-community/netinfo';
import geohash from 'ngeohash';
import { incidentService } from '../services/incidentService';
import { geofenceService } from '../services/geofenceService';
import websocketService from '../services/websocketService';
import ReportIncidentModal from '../components/ReportIncidentModal';
import HotspotZoneBanner from '../components/HotspotZoneBanner';
import OfflineIndicator from '../components/OfflineIndicator';
import { useMarkerClustering, ClusterMarker } from '../components/MarkerCluster';
import { MapMarkerSkeleton } from '../components/LoadingSkeleton';
import { lightHaptic, warningHaptic, successHaptic } from '../utils/haptics';
import performanceMonitor from '../utils/performance';

const INCIDENT_COLORS = {
  hijacking: '#EF4444', // red
  mugging: '#F97316', // orange
  accident: '#3B82F6', // blue
};

const HEAT_ZONE_COLORS = {
  hijacking: 'rgba(239, 68, 68, 0.3)', // red with transparency
  mugging: 'rgba(249, 115, 22, 0.3)', // orange with transparency
  accident: 'rgba(59, 130, 246, 0.3)', // blue with transparency
};

const HOTSPOT_ZONE_COLORS = {
  low: 'rgba(251, 191, 36, 0.25)', // yellow
  medium: 'rgba(251, 146, 60, 0.3)', // orange
  high: 'rgba(239, 68, 68, 0.35)', // red
  critical: 'rgba(220, 38, 38, 0.4)', // dark red
};

const HOTSPOT_ZONE_STROKE_COLORS = {
  low: '#F59E0B',
  medium: '#F97316',
  high: '#EF4444',
  critical: '#DC2626',
};

const MapScreen = () => {
  const [userLocation, setUserLocation] = useState(null);
  const [incidents, setIncidents] = useState([]);
  const [heatZones, setHeatZones] = useState([]);
  const [hotspotZones, setHotspotZones] = useState([]);
  const [showHeatZones, setShowHeatZones] = useState(true);
  const [showHotspotZones, setShowHotspotZones] = useState(true);
  const [selectedIncident, setSelectedIncident] = useState(null);
  const [loading, setLoading] = useState(true);
  const [locationPermission, setLocationPermission] = useState(false);
  const [reportModalVisible, setReportModalVisible] = useState(false);
  const [isOnline, setIsOnline] = useState(true);
  const [verifyingIncident, setVerifyingIncident] = useState(false);
  const [verifiedIncidents, setVerifiedIncidents] = useState(new Set());
  const [zoneAlert, setZoneAlert] = useState(null);
  const [mapZoom, setMapZoom] = useState(12);
  const mapRef = useRef(null);
  const locationWatchRef = useRef(null);

  // Use marker clustering for better performance
  const clusteredMarkers = useMarkerClustering(incidents, mapZoom);

  useEffect(() => {
    requestLocationPermission();
    setupConnectivityListener();
    initializeWebSocket();

    // Cleanup on unmount
    return () => {
      websocketService.disconnect();
      
      // Stop location tracking
      if (locationWatchRef.current) {
        locationWatchRef.current.remove();
      }
    };
  }, []);

  useEffect(() => {
    if (userLocation) {
      fetchNearbyIncidents();
      fetchHeatmapData();
      fetchHotspotZones();
      updateWebSocketLocation(userLocation);
    }
  }, [userLocation]);

  const initializeWebSocket = async () => {
    try {
      const connected = await websocketService.connect();
      
      if (connected) {
        // Subscribe to new incident events
        websocketService.onNewIncident((incident) => {
          handleNewIncidentFromWebSocket(incident);
        });

        // Join geofence channel for zone alerts
        await websocketService.joinGeofenceChannel();

        // Subscribe to zone entry events
        websocketService.onZoneEntered((data) => {
          handleZoneEntered(data);
        });

        // Subscribe to zone exit events
        websocketService.onZoneExited((data) => {
          handleZoneExited(data);
        });

        // Subscribe to zone approaching events (premium users)
        websocketService.onZoneApproaching((data) => {
          handleZoneApproaching(data);
        });

        // Start background location tracking
        startBackgroundLocationTracking();
      }
    } catch (error) {
      console.error('Failed to initialize WebSocket:', error);
    }
  };

  const updateWebSocketLocation = (location) => {
    // Calculate geohash for current location
    const currentGeohash = geohash.encode(location.latitude, location.longitude, 6);
    
    // Join incident channel for this geohash
    websocketService.joinIncidentChannel(currentGeohash);
    
    // Update location on the server
    websocketService.updateLocation(location.latitude, location.longitude);
  };

  const handleNewIncidentFromWebSocket = (incident) => {
    console.log('Received new incident via WebSocket:', incident);
    
    // Add the new incident to the map if not already present
    setIncidents(prev => {
      const exists = prev.some(i => i.id === incident.id);
      if (exists) return prev;
      
      // Transform incident data to match expected format
      const newIncident = {
        id: incident.id,
        type: incident.type,
        location: {
          latitude: incident.latitude,
          longitude: incident.longitude,
        },
        description: incident.description,
        photo_url: incident.photo_url,
        verification_count: incident.verification_count,
        is_verified: incident.is_verified,
        inserted_at: incident.inserted_at,
      };
      
      return [newIncident, ...prev];
    });
    
    // Show a brief notification (optional)
    Alert.alert(
      'New Incident Nearby',
      `A ${incident.type} was just reported in your area.`,
      [{ text: 'OK' }],
      { cancelable: true }
    );
  };

  const setupConnectivityListener = () => {
    const unsubscribe = NetInfo.addEventListener(state => {
      setIsOnline(state.isConnected);
      
      // Try to sync offline reports when connection is restored
      if (state.isConnected) {
        syncOfflineReports();
      }
    });

    return unsubscribe;
  };

  const syncOfflineReports = async () => {
    try {
      const result = await incidentService.syncOfflineReports();
      if (result.success > 0) {
        Alert.alert(
          'Reports Synced',
          `${result.success} queued report(s) have been submitted successfully.`
        );
        fetchNearbyIncidents(); // Refresh the map
      }
    } catch (error) {
      console.error('Error syncing offline reports:', error);
    }
  };

  const requestLocationPermission = async () => {
    try {
      const { status } = await Location.requestForegroundPermissionsAsync();
      
      if (status !== 'granted') {
        Alert.alert(
          'Permission Denied',
          'Location permission is required to use this app'
        );
        setLoading(false);
        return;
      }

      setLocationPermission(true);
      getCurrentLocation();
    } catch (error) {
      console.error('Error requesting location permission:', error);
      setLoading(false);
    }
  };

  const getCurrentLocation = async () => {
    try {
      const location = await Location.getCurrentPositionAsync({
        accuracy: Location.Accuracy.High,
      });

      const coords = {
        latitude: location.coords.latitude,
        longitude: location.coords.longitude,
      };

      setUserLocation(coords);
      setLoading(false);

      // Center map on user location
      if (mapRef.current) {
        mapRef.current.animateToRegion({
          ...coords,
          latitudeDelta: 0.05,
          longitudeDelta: 0.05,
        });
      }
    } catch (error) {
      console.error('Error getting current location:', error);
      setLoading(false);
    }
  };

  const fetchNearbyIncidents = async () => {
    if (!userLocation) return;

    try {
      const data = await performanceMonitor.measureAsync(
        'Fetch Nearby Incidents',
        () => incidentService.getNearby(
          userLocation.latitude,
          userLocation.longitude,
          5000 // 5km radius
        )
      );
      setIncidents(data);
    } catch (error) {
      console.error('Error fetching incidents:', error);
      Alert.alert('Error', 'Failed to load nearby incidents');
    }
  };

  const fetchHeatmapData = async () => {
    if (!isOnline) return;

    try {
      const data = await incidentService.getHeatmap();
      setHeatZones(data.clusters || []);
    } catch (error) {
      console.error('Error fetching heatmap data:', error);
      // Don't show alert for heatmap errors - it's not critical
    }
  };

  const fetchHotspotZones = async () => {
    if (!isOnline) return;

    try {
      const zones = await geofenceService.getZones();
      setHotspotZones(zones || []);
    } catch (error) {
      console.error('Error fetching hotspot zones:', error);
      // Don't show alert for zone errors - it's not critical
    }
  };

  const startBackgroundLocationTracking = async () => {
    try {
      // Request background location permission
      const { status } = await Location.requestBackgroundPermissionsAsync();
      
      if (status !== 'granted') {
        console.warn('Background location permission not granted');
        return;
      }

      // Start watching location with high accuracy
      locationWatchRef.current = await Location.watchPositionAsync(
        {
          accuracy: Location.Accuracy.High,
          timeInterval: 10000, // Update every 10 seconds
          distanceInterval: 50, // Or when user moves 50 meters
        },
        (location) => {
          const coords = {
            latitude: location.coords.latitude,
            longitude: location.coords.longitude,
          };

          // Update user location state
          setUserLocation(coords);

          // Send location update to geofence channel
          websocketService.updateGeofenceLocation(coords.latitude, coords.longitude);
        }
      );
    } catch (error) {
      console.error('Error starting background location tracking:', error);
    }
  };

  const handleZoneEntered = (data) => {
    console.log('Entered hotspot zone:', data);
    
    // Show zone alert banner
    setZoneAlert({
      zone: data,
      action: 'entered',
    });

    // Auto-dismiss after 10 seconds
    setTimeout(() => {
      setZoneAlert(null);
    }, 10000);

    // Show system alert
    Alert.alert(
      'Hotspot Zone Alert',
      data.message,
      [{ text: 'OK' }],
      { cancelable: true }
    );
  };

  const handleZoneExited = (data) => {
    console.log('Exited hotspot zone:', data);
    
    // Show brief exit notification
    setZoneAlert({
      zone: data,
      action: 'exited',
    });

    // Auto-dismiss after 5 seconds
    setTimeout(() => {
      setZoneAlert(null);
    }, 5000);
  };

  const handleZoneApproaching = (data) => {
    console.log('Approaching hotspot zone:', data);
    
    // Show approaching alert (premium feature)
    setZoneAlert({
      zone: data,
      action: 'approaching',
    });

    // Auto-dismiss after 8 seconds
    setTimeout(() => {
      setZoneAlert(null);
    }, 8000);

    // Show system alert
    Alert.alert(
      'Approaching Hotspot Zone',
      data.message,
      [{ text: 'OK' }],
      { cancelable: true }
    );
  };

  const centerOnUserLocation = () => {
    if (userLocation && mapRef.current) {
      mapRef.current.animateToRegion({
        ...userLocation,
        latitudeDelta: 0.05,
        longitudeDelta: 0.05,
      }, 1000);
    }
  };

  const formatTimeAgo = (timestamp) => {
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
      return `${Math.round(meters)}m away`;
    }
    return `${(meters / 1000).toFixed(1)}km away`;
  };

  const handleReportSuccess = (incident) => {
    // Add the new incident to the map immediately
    setIncidents(prev => [incident, ...prev]);
    
    // Refresh heatmap data after a new incident is reported
    fetchHeatmapData();
    
    // Show success message
    Alert.alert(
      'Success',
      'Your incident report has been submitted successfully.'
    );
  };

  const toggleHeatZones = () => {
    lightHaptic();
    setShowHeatZones(prev => !prev);
  };

  const toggleHotspotZones = () => {
    lightHaptic();
    setShowHotspotZones(prev => !prev);
  };

  const handleVerifyIncident = async (incidentId) => {
    if (!isOnline) {
      warningHaptic();
      Alert.alert('Offline', 'You need to be online to verify incidents.');
      return;
    }

    if (verifiedIncidents.has(incidentId)) {
      warningHaptic();
      Alert.alert('Already Verified', 'You have already verified this incident.');
      return;
    }

    lightHaptic();
    setVerifyingIncident(true);

    try {
      const result = await incidentService.verify(incidentId);
      
      // Update the incident in the list with new verification count
      setIncidents(prev =>
        prev.map(incident =>
          incident.id === incidentId
            ? {
                ...incident,
                verification_count: result.verification_count,
                is_verified: result.is_verified,
              }
            : incident
        )
      );

      // Update selected incident if it's the one being verified
      if (selectedIncident && selectedIncident.id === incidentId) {
        setSelectedIncident({
          ...selectedIncident,
          verification_count: result.verification_count,
          is_verified: result.is_verified,
        });
      }

      // Mark as verified by this user
      setVerifiedIncidents(prev => new Set([...prev, incidentId]));

      successHaptic();
      Alert.alert('Success', result.message || 'Incident verified successfully!');
    } catch (error) {
      warningHaptic();
      const errorMessage = error.response?.data?.error || 'Failed to verify incident';
      Alert.alert('Error', errorMessage);
    } finally {
      setVerifyingIncident(false);
    }
  };

  if (loading) {
    return (
      <View style={styles.loadingContainer}>
        <MapMarkerSkeleton />
      </View>
    );
  }

  if (!locationPermission) {
    return (
      <View style={styles.errorContainer}>
        <Text style={styles.errorText}>Location permission is required</Text>
        <TouchableOpacity
          style={styles.retryButton}
          onPress={requestLocationPermission}
        >
          <Text style={styles.retryButtonText}>Grant Permission</Text>
        </TouchableOpacity>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <MapView
        ref={mapRef}
        style={styles.map}
        provider={PROVIDER_GOOGLE}
        initialRegion={
          userLocation
            ? {
                ...userLocation,
                latitudeDelta: 0.05,
                longitudeDelta: 0.05,
              }
            : undefined
        }
        showsUserLocation={true}
        showsMyLocationButton={false}
        onRegionChangeComplete={(region) => {
          // Estimate zoom level from latitudeDelta
          const zoom = Math.round(Math.log(360 / region.latitudeDelta) / Math.LN2);
          setMapZoom(zoom);
        }}
      >
        {/* Hotspot zones - render first (geofenced areas) */}
        {showHotspotZones && hotspotZones.map((zone) => (
          <Circle
            key={`hotspot-zone-${zone.id}`}
            center={{
              latitude: zone.center.latitude,
              longitude: zone.center.longitude,
            }}
            radius={zone.radius_meters}
            fillColor={HOTSPOT_ZONE_COLORS[zone.risk_level] || 'rgba(128, 128, 128, 0.25)'}
            strokeColor={HOTSPOT_ZONE_STROKE_COLORS[zone.risk_level] || '#808080'}
            strokeWidth={3}
          />
        ))}

        {/* Heat zones - render second */}
        {showHeatZones && heatZones.map((zone, index) => (
          <Circle
            key={`heat-zone-${index}`}
            center={{
              latitude: zone.center.latitude,
              longitude: zone.center.longitude,
            }}
            radius={zone.radius}
            fillColor={HEAT_ZONE_COLORS[zone.dominant_type] || 'rgba(128, 128, 128, 0.3)'}
            strokeColor={INCIDENT_COLORS[zone.dominant_type] || '#808080'}
            strokeWidth={2}
          />
        ))}

        {/* Clustered incident markers for better performance */}
        {clusteredMarkers.map((cluster, index) => (
          <ClusterMarker
            key={cluster.type === 'single' ? cluster.incident.id : `cluster-${index}`}
            cluster={cluster}
            onPress={(data) => {
              lightHaptic();
              if (Array.isArray(data)) {
                // Cluster tapped - zoom in
                if (mapRef.current) {
                  mapRef.current.animateToRegion({
                    latitude: cluster.latitude,
                    longitude: cluster.longitude,
                    latitudeDelta: 0.01,
                    longitudeDelta: 0.01,
                  });
                }
              } else {
                // Single incident tapped
                setSelectedIncident(data);
              }
            }}
          />
        ))}
      </MapView>

      {/* Hotspot zone alert banner */}
      {zoneAlert && (
        <HotspotZoneBanner
          zone={zoneAlert.zone}
          action={zoneAlert.action}
          onDismiss={() => setZoneAlert(null)}
        />
      )}

      {/* Hotspot zones toggle button */}
      <TouchableOpacity
        style={[styles.hotspotZoneToggle, showHotspotZones && styles.hotspotZoneToggleActive]}
        onPress={toggleHotspotZones}
      >
        <Text style={styles.hotspotZoneToggleText}>
          {showHotspotZones ? '🚨' : '🚨'}
        </Text>
        <Text style={[styles.hotspotZoneToggleLabel, showHotspotZones && styles.hotspotZoneToggleLabelActive]}>
          Hotspot Zones
        </Text>
      </TouchableOpacity>

      {/* Heat zones toggle button */}
      <TouchableOpacity
        style={[styles.heatZoneToggle, showHeatZones && styles.heatZoneToggleActive]}
        onPress={toggleHeatZones}
      >
        <Text style={styles.heatZoneToggleText}>
          {showHeatZones ? '🔥' : '🔥'}
        </Text>
        <Text style={[styles.heatZoneToggleLabel, showHeatZones && styles.heatZoneToggleLabelActive]}>
          Heat Zones
        </Text>
      </TouchableOpacity>

      {/* Center on user location button */}
      <TouchableOpacity
        style={styles.centerButton}
        onPress={centerOnUserLocation}
      >
        <Text style={styles.centerButtonText}>📍</Text>
      </TouchableOpacity>

      {/* Zoom controls */}
      <View style={styles.zoomControls}>
        <TouchableOpacity
          style={styles.zoomButton}
          onPress={() => {
            if (mapRef.current) {
              mapRef.current.getCamera().then((camera) => {
                camera.zoom += 1;
                mapRef.current.animateCamera(camera);
              });
            }
          }}
        >
          <Text style={styles.zoomButtonText}>+</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={styles.zoomButton}
          onPress={() => {
            if (mapRef.current) {
              mapRef.current.getCamera().then((camera) => {
                camera.zoom -= 1;
                mapRef.current.animateCamera(camera);
              });
            }
          }}
        >
          <Text style={styles.zoomButtonText}>−</Text>
        </TouchableOpacity>
      </View>

      {/* Floating Report Incident Button */}
      <TouchableOpacity
        style={styles.reportButton}
        onPress={() => {
          lightHaptic();
          setReportModalVisible(true);
        }}
      >
        <Text style={styles.reportButtonText}>+ Report Incident</Text>
      </TouchableOpacity>

      {/* Offline Indicator */}
      <OfflineIndicator />

      {/* Report Incident Modal */}
      <ReportIncidentModal
        visible={reportModalVisible}
        onClose={() => setReportModalVisible(false)}
        onReportSuccess={handleReportSuccess}
      />

      {/* Incident details card */}
      {selectedIncident && (
        <View style={styles.incidentCard}>
          <View style={styles.incidentHeader}>
            <View
              style={[
                styles.incidentTypeBadge,
                { backgroundColor: INCIDENT_COLORS[selectedIncident.type] },
              ]}
            >
              <Text style={styles.incidentTypeText}>
                {selectedIncident.type.toUpperCase()}
              </Text>
            </View>
            <TouchableOpacity onPress={() => setSelectedIncident(null)}>
              <Text style={styles.closeButton}>✕</Text>
            </TouchableOpacity>
          </View>

          <View style={styles.incidentInfo}>
            <Text style={styles.incidentTime}>
              {formatTimeAgo(selectedIncident.inserted_at)}
            </Text>
            {selectedIncident.distance && (
              <Text style={styles.incidentDistance}>
                {formatDistance(selectedIncident.distance)}
              </Text>
            )}
          </View>

          {selectedIncident.description && (
            <Text style={styles.incidentDescription}>
              {selectedIncident.description}
            </Text>
          )}

          <View style={styles.verificationInfo}>
            <View style={styles.verificationStatus}>
              {selectedIncident.is_verified && (
                <View style={styles.verifiedBadge}>
                  <Text style={styles.verifiedBadgeText}>✓ Verified</Text>
                </View>
              )}
              <Text style={styles.verificationCount}>
                {selectedIncident.verification_count} upvote{selectedIncident.verification_count !== 1 ? 's' : ''}
              </Text>
            </View>
            
            <TouchableOpacity
              style={[
                styles.verifyButton,
                (verifiedIncidents.has(selectedIncident.id) || verifyingIncident) && styles.verifyButtonDisabled
              ]}
              onPress={() => handleVerifyIncident(selectedIncident.id)}
              disabled={verifiedIncidents.has(selectedIncident.id) || verifyingIncident}
            >
              {verifyingIncident ? (
                <ActivityIndicator size="small" color="#fff" />
              ) : (
                <Text style={styles.verifyButtonText}>
                  {verifiedIncidents.has(selectedIncident.id) ? '✓ Verified' : 'Verify'}
                </Text>
              )}
            </TouchableOpacity>
          </View>
        </View>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  map: {
    flex: 1,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#fff',
  },
  loadingText: {
    marginTop: 16,
    fontSize: 16,
    color: '#666',
  },
  errorContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#fff',
    padding: 20,
  },
  errorText: {
    fontSize: 16,
    color: '#666',
    textAlign: 'center',
    marginBottom: 20,
  },
  retryButton: {
    backgroundColor: '#EF4444',
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 8,
  },
  retryButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  hotspotZoneToggle: {
    position: 'absolute',
    top: 60,
    right: 20,
    backgroundColor: '#fff',
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 20,
    flexDirection: 'row',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.25,
    shadowRadius: 3.84,
    elevation: 5,
    borderWidth: 2,
    borderColor: '#E5E7EB',
  },
  hotspotZoneToggleActive: {
    backgroundColor: '#FEE2E2',
    borderColor: '#EF4444',
  },
  hotspotZoneToggleText: {
    fontSize: 18,
    marginRight: 6,
  },
  hotspotZoneToggleLabel: {
    fontSize: 12,
    fontWeight: '600',
    color: '#6B7280',
  },
  hotspotZoneToggleLabelActive: {
    color: '#991B1B',
  },
  heatZoneToggle: {
    position: 'absolute',
    top: 110,
    right: 20,
    backgroundColor: '#fff',
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 20,
    flexDirection: 'row',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.25,
    shadowRadius: 3.84,
    elevation: 5,
    borderWidth: 2,
    borderColor: '#E5E7EB',
  },
  heatZoneToggleActive: {
    backgroundColor: '#FEF3C7',
    borderColor: '#F59E0B',
  },
  heatZoneToggleText: {
    fontSize: 18,
    marginRight: 6,
  },
  heatZoneToggleLabel: {
    fontSize: 12,
    fontWeight: '600',
    color: '#6B7280',
  },
  heatZoneToggleLabelActive: {
    color: '#92400E',
  },
  centerButton: {
    position: 'absolute',
    bottom: 120,
    right: 20,
    backgroundColor: '#fff',
    width: 50,
    height: 50,
    borderRadius: 25,
    justifyContent: 'center',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.25,
    shadowRadius: 3.84,
    elevation: 5,
  },
  centerButtonText: {
    fontSize: 24,
  },
  zoomControls: {
    position: 'absolute',
    bottom: 200,
    right: 20,
    backgroundColor: '#fff',
    borderRadius: 8,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.25,
    shadowRadius: 3.84,
    elevation: 5,
  },
  zoomButton: {
    width: 50,
    height: 50,
    justifyContent: 'center',
    alignItems: 'center',
    borderBottomWidth: 1,
    borderBottomColor: '#E5E7EB',
  },
  zoomButtonText: {
    fontSize: 24,
    color: '#374151',
    fontWeight: '600',
  },
  reportButton: {
    position: 'absolute',
    bottom: 20,
    left: 20,
    right: 20,
    backgroundColor: '#EF4444',
    paddingVertical: 16,
    borderRadius: 12,
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 4.65,
    elevation: 8,
  },
  reportButtonText: {
    color: '#fff',
    fontSize: 18,
    fontWeight: '700',
  },
  offlineIndicator: {
    position: 'absolute',
    top: 60,
    left: 20,
    right: 20,
    backgroundColor: '#FEF3C7',
    paddingVertical: 8,
    paddingHorizontal: 16,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#FCD34D',
  },
  offlineText: {
    color: '#92400E',
    fontSize: 14,
    fontWeight: '600',
    textAlign: 'center',
  },
  incidentCard: {
    position: 'absolute',
    bottom: 20,
    left: 20,
    right: 20,
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.25,
    shadowRadius: 3.84,
    elevation: 5,
  },
  incidentHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 12,
  },
  incidentTypeBadge: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 6,
  },
  incidentTypeText: {
    color: '#fff',
    fontSize: 12,
    fontWeight: '700',
  },
  closeButton: {
    fontSize: 24,
    color: '#9CA3AF',
  },
  incidentInfo: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 8,
  },
  incidentTime: {
    fontSize: 14,
    color: '#6B7280',
  },
  incidentDistance: {
    fontSize: 14,
    color: '#6B7280',
    fontWeight: '600',
  },
  incidentDescription: {
    fontSize: 14,
    color: '#374151',
    marginBottom: 12,
    lineHeight: 20,
  },
  verificationInfo: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingTop: 12,
    borderTopWidth: 1,
    borderTopColor: '#E5E7EB',
  },
  verificationStatus: {
    flexDirection: 'column',
    gap: 4,
  },
  verifiedBadge: {
    backgroundColor: '#D1FAE5',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 4,
    alignSelf: 'flex-start',
  },
  verifiedBadgeText: {
    fontSize: 12,
    color: '#065F46',
    fontWeight: '600',
  },
  verificationCount: {
    fontSize: 14,
    color: '#6B7280',
  },
  verifyButton: {
    backgroundColor: '#3B82F6',
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 6,
    minWidth: 80,
    alignItems: 'center',
  },
  verifyButtonDisabled: {
    backgroundColor: '#9CA3AF',
  },
  verifyButtonText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '600',
  },
});

export default MapScreen;
