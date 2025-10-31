import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  TouchableOpacity,
  ActivityIndicator,
  Alert,
  ScrollView,
  Linking,
  Platform,
} from 'react-native';
import * as Location from 'expo-location';
import { travelService } from '../services/travelService';

const TravelModeScreen = ({ navigation }) => {
  const [currentLocation, setCurrentLocation] = useState(null);
  const [destination, setDestination] = useState('');
  const [destinationCoords, setDestinationCoords] = useState(null);
  const [loading, setLoading] = useState(false);
  const [analyzing, setAnalyzing] = useState(false);
  const [safetyReport, setSafetyReport] = useState(null);
  const [alternativeRoutes, setAlternativeRoutes] = useState(null);
  const [showAlternatives, setShowAlternatives] = useState(false);
  const [showSegments, setShowSegments] = useState(false);
  const [isJourneyActive, setIsJourneyActive] = useState(false);
  const [realtimeUpdates, setRealtimeUpdates] = useState(null);

  useEffect(() => {
    getCurrentLocation();
  }, []);

  const getCurrentLocation = async () => {
    try {
      setLoading(true);
      const { status } = await Location.requestForegroundPermissionsAsync();
      if (status !== 'granted') {
        Alert.alert('Permission Denied', 'Location permission is required for Travel Mode');
        return;
      }

      const location = await Location.getCurrentPositionAsync({});
      setCurrentLocation({
        latitude: location.coords.latitude,
        longitude: location.coords.longitude,
      });
    } catch (error) {
      console.error('Failed to get location:', error);
      Alert.alert('Error', 'Failed to get your current location');
    } finally {
      setLoading(false);
    }
  };

  const handleDestinationSearch = async () => {
    if (!destination.trim()) {
      Alert.alert('Error', 'Please enter a destination');
      return;
    }

    try {
      setLoading(true);
      // Use geocoding to convert address to coordinates
      const results = await Location.geocodeAsync(destination);
      
      if (results.length === 0) {
        Alert.alert('Not Found', 'Could not find the destination. Please try a different address.');
        return;
      }

      setDestinationCoords({
        latitude: results[0].latitude,
        longitude: results[0].longitude,
      });
    } catch (error) {
      console.error('Geocoding error:', error);
      Alert.alert('Error', 'Failed to find destination');
    } finally {
      setLoading(false);
    }
  };

  const handleAnalyzeRoute = async () => {
    if (!currentLocation || !destinationCoords) {
      Alert.alert('Error', 'Please set both origin and destination');
      return;
    }

    try {
      setAnalyzing(true);
      const report = await travelService.analyzeRoute(currentLocation, destinationCoords);
      setSafetyReport(report);
      
      // Also fetch alternative routes
      const alternatives = await travelService.getAlternativeRoutes(currentLocation, destinationCoords);
      setAlternativeRoutes(alternatives);
    } catch (error) {
      console.error('Route analysis error:', error);
      Alert.alert('Error', error.message || 'Failed to analyze route');
    } finally {
      setAnalyzing(false);
    }
  };

  const handleStartJourney = () => {
    setIsJourneyActive(true);
    startRealtimeUpdates();
    
    // Offer to open navigation app
    Alert.alert(
      'Start Navigation',
      'Would you like to open navigation in Google Maps or Apple Maps?',
      [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Google Maps', onPress: () => openGoogleMaps() },
        { text: 'Apple Maps', onPress: () => openAppleMaps() },
      ]
    );
  };

  const handleStopJourney = () => {
    setIsJourneyActive(false);
    setRealtimeUpdates(null);
  };

  const openGoogleMaps = () => {
    if (!destinationCoords) return;
    
    const url = Platform.select({
      ios: `comgooglemaps://?daddr=${destinationCoords.latitude},${destinationCoords.longitude}&directionsmode=driving`,
      android: `google.navigation:q=${destinationCoords.latitude},${destinationCoords.longitude}&mode=d`,
    });
    
    const webUrl = `https://www.google.com/maps/dir/?api=1&destination=${destinationCoords.latitude},${destinationCoords.longitude}&travelmode=driving`;
    
    Linking.canOpenURL(url).then((supported) => {
      if (supported) {
        Linking.openURL(url);
      } else {
        Linking.openURL(webUrl);
      }
    });
  };

  const openAppleMaps = () => {
    if (!destinationCoords) return;
    
    const url = `maps://app?daddr=${destinationCoords.latitude},${destinationCoords.longitude}&dirflg=d`;
    
    Linking.canOpenURL(url).then((supported) => {
      if (supported) {
        Linking.openURL(url);
      } else {
        Alert.alert('Error', 'Apple Maps is not available on this device');
      }
    });
  };

  const openNavigationForRoute = (waypoints) => {
    // For alternative routes with waypoints
    if (!waypoints || waypoints.length < 2) return;
    
    const destination = waypoints[waypoints.length - 1];
    const waypointsParam = waypoints
      .slice(1, -1)
      .map(wp => `${wp.latitude},${wp.longitude}`)
      .join('|');
    
    const url = `https://www.google.com/maps/dir/?api=1&destination=${destination.latitude},${destination.longitude}&waypoints=${waypointsParam}&travelmode=driving`;
    
    Linking.openURL(url);
  };

  const startRealtimeUpdates = async () => {
    // Poll for updates every 30 seconds during active journey
    const updateInterval = setInterval(async () => {
      if (!isJourneyActive) {
        clearInterval(updateInterval);
        return;
      }

      try {
        const location = await Location.getCurrentPositionAsync({});
        const updates = await travelService.getRealtimeUpdates(
          {
            latitude: location.coords.latitude,
            longitude: location.coords.longitude,
          },
          destinationCoords
        );
        setRealtimeUpdates(updates);

        // Show alerts if any
        if (updates.alerts && updates.alerts.length > 0) {
          const criticalAlerts = updates.alerts.filter(alert => alert.includes('⚠️'));
          if (criticalAlerts.length > 0) {
            Alert.alert('Safety Alert', criticalAlerts[0]);
          }
        }
      } catch (error) {
        console.error('Failed to get realtime updates:', error);
      }
    }, 30000); // Update every 30 seconds

    return () => clearInterval(updateInterval);
  };

  const getRiskColor = (riskLevel) => {
    switch (riskLevel) {
      case 'safe':
        return '#28A745';
      case 'moderate':
        return '#FFC107';
      case 'caution':
        return '#FF9800';
      case 'dangerous':
        return '#DC3545';
      default:
        return '#6C757D';
    }
  };

  const getRiskIcon = (riskLevel) => {
    switch (riskLevel) {
      case 'safe':
        return '✓';
      case 'moderate':
        return '⚠';
      case 'caution':
        return '⚠';
      case 'dangerous':
        return '⚠';
      default:
        return '?';
    }
  };

  if (loading && !currentLocation) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color="#E63946" />
        <Text style={styles.loadingText}>Getting your location...</Text>
      </View>
    );
  }

  return (
    <ScrollView style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>Travel Mode</Text>
        <Text style={styles.subtitle}>Plan your route and check safety conditions</Text>
      </View>

      {/* Origin */}
      <View style={styles.card}>
        <Text style={styles.label}>From (Current Location)</Text>
        <View style={styles.locationDisplay}>
          <Text style={styles.locationIcon}>📍</Text>
          <Text style={styles.locationText}>
            {currentLocation
              ? `${currentLocation.latitude.toFixed(4)}, ${currentLocation.longitude.toFixed(4)}`
              : 'Loading...'}
          </Text>
        </View>
      </View>

      {/* Destination */}
      <View style={styles.card}>
        <Text style={styles.label}>To (Destination)</Text>
        <View style={styles.inputContainer}>
          <TextInput
            style={styles.input}
            placeholder="Enter destination address"
            value={destination}
            onChangeText={setDestination}
            onSubmitEditing={handleDestinationSearch}
          />
          <TouchableOpacity
            style={styles.searchButton}
            onPress={handleDestinationSearch}
            disabled={loading}
          >
            {loading ? (
              <ActivityIndicator size="small" color="#fff" />
            ) : (
              <Text style={styles.searchButtonText}>Search</Text>
            )}
          </TouchableOpacity>
        </View>
        {destinationCoords && (
          <View style={styles.locationDisplay}>
            <Text style={styles.locationIcon}>🎯</Text>
            <Text style={styles.locationText}>
              {`${destinationCoords.latitude.toFixed(4)}, ${destinationCoords.longitude.toFixed(4)}`}
            </Text>
          </View>
        )}
      </View>

      {/* Analyze Button */}
      {currentLocation && destinationCoords && (
        <TouchableOpacity
          style={styles.analyzeButton}
          onPress={handleAnalyzeRoute}
          disabled={analyzing}
        >
          {analyzing ? (
            <ActivityIndicator color="#fff" />
          ) : (
            <Text style={styles.analyzeButtonText}>Analyze Route Safety</Text>
          )}
        </TouchableOpacity>
      )}

      {/* Safety Report */}
      {safetyReport && (
        <View style={styles.reportCard}>
          <View style={styles.reportHeader}>
            <Text style={styles.reportTitle}>Safety Report</Text>
            <View
              style={[
                styles.riskBadge,
                { backgroundColor: getRiskColor(safetyReport.risk_level) },
              ]}
            >
              <Text style={styles.riskBadgeText}>
                {getRiskIcon(safetyReport.risk_level)} {safetyReport.risk_level.toUpperCase()}
              </Text>
            </View>
          </View>

          {/* Safety Score */}
          <View style={styles.scoreContainer}>
            <Text style={styles.scoreLabel}>Safety Score</Text>
            <Text
              style={[
                styles.scoreValue,
                { color: getRiskColor(safetyReport.risk_level) },
              ]}
            >
              {safetyReport.safety_score}/100
            </Text>
          </View>

          {/* Incident Summary */}
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Recent Incidents (48h)</Text>
            <View style={styles.statsGrid}>
              <View style={styles.statItem}>
                <Text style={styles.statValue}>{safetyReport.total_incidents}</Text>
                <Text style={styles.statLabel}>Total</Text>
              </View>
              <View style={styles.statItem}>
                <Text style={[styles.statValue, { color: '#DC3545' }]}>
                  {safetyReport.incident_counts.hijacking}
                </Text>
                <Text style={styles.statLabel}>Hijackings</Text>
              </View>
              <View style={styles.statItem}>
                <Text style={[styles.statValue, { color: '#FF9800' }]}>
                  {safetyReport.incident_counts.mugging}
                </Text>
                <Text style={styles.statLabel}>Muggings</Text>
              </View>
              <View style={styles.statItem}>
                <Text style={[styles.statValue, { color: '#2196F3' }]}>
                  {safetyReport.incident_counts.accident}
                </Text>
                <Text style={styles.statLabel}>Accidents</Text>
              </View>
            </View>
          </View>

          {/* Hotspot Zones */}
          {safetyReport.hotspot_zones.total > 0 && (
            <View style={styles.section}>
              <Text style={styles.sectionTitle}>Hotspot Zones</Text>
              <View style={styles.statsGrid}>
                <View style={styles.statItem}>
                  <Text style={styles.statValue}>{safetyReport.hotspot_zones.total}</Text>
                  <Text style={styles.statLabel}>Total Zones</Text>
                </View>
                {safetyReport.hotspot_zones.critical > 0 && (
                  <View style={styles.statItem}>
                    <Text style={[styles.statValue, { color: '#DC3545' }]}>
                      {safetyReport.hotspot_zones.critical}
                    </Text>
                    <Text style={styles.statLabel}>Critical</Text>
                  </View>
                )}
                {safetyReport.hotspot_zones.high > 0 && (
                  <View style={styles.statItem}>
                    <Text style={[styles.statValue, { color: '#FF5722' }]}>
                      {safetyReport.hotspot_zones.high}
                    </Text>
                    <Text style={styles.statLabel}>High</Text>
                  </View>
                )}
              </View>
            </View>
          )}

          {/* Recommendations */}
          <View style={styles.section}>
            <Text style={styles.sectionTitle}>Recommendations</Text>
            {safetyReport.recommendations.map((rec, index) => (
              <View key={index} style={styles.recommendationItem}>
                <Text style={styles.recommendationBullet}>•</Text>
                <Text style={styles.recommendationText}>{rec}</Text>
              </View>
            ))}
          </View>

          {/* Route Segments */}
          {safetyReport.segments && safetyReport.segments.length > 0 && (
            <View style={styles.section}>
              <TouchableOpacity
                style={styles.sectionHeader}
                onPress={() => setShowSegments(!showSegments)}
              >
                <Text style={styles.sectionTitle}>Route Breakdown by Segment</Text>
                <Text style={styles.expandIcon}>{showSegments ? '▼' : '▶'}</Text>
              </TouchableOpacity>
              
              {showSegments && (
                <View style={styles.segmentsContainer}>
                  {safetyReport.segments.map((segment, index) => (
                    <View key={index} style={styles.segmentCard}>
                      <View style={styles.segmentHeader}>
                        <Text style={styles.segmentNumber}>Segment {segment.segment_number}</Text>
                        <View
                          style={[
                            styles.segmentRiskBadge,
                            { backgroundColor: getRiskColor(segment.risk_level) },
                          ]}
                        >
                          <Text style={styles.segmentRiskText}>
                            {segment.risk_level.toUpperCase()}
                          </Text>
                        </View>
                      </View>
                      <View style={styles.segmentStats}>
                        <Text style={styles.segmentStat}>
                          Score: {segment.safety_score}/100
                        </Text>
                        <Text style={styles.segmentStat}>
                          Incidents: {segment.incident_count}
                        </Text>
                        {segment.critical_zones > 0 && (
                          <Text style={[styles.segmentStat, { color: '#DC3545' }]}>
                            ⚠ {segment.critical_zones} Critical Zone(s)
                          </Text>
                        )}
                      </View>
                    </View>
                  ))}
                </View>
              )}
            </View>
          )}

          {/* Journey Controls */}
          <View style={styles.section}>
            {!isJourneyActive ? (
              <TouchableOpacity
                style={styles.startJourneyButton}
                onPress={handleStartJourney}
              >
                <Text style={styles.startJourneyText}>🚗 Start Journey</Text>
              </TouchableOpacity>
            ) : (
              <TouchableOpacity
                style={styles.stopJourneyButton}
                onPress={handleStopJourney}
              >
                <Text style={styles.stopJourneyText}>⏹ Stop Journey</Text>
              </TouchableOpacity>
            )}
          </View>
        </View>
      )}

      {/* Alternative Routes */}
      {alternativeRoutes && (
        <View style={styles.card}>
          <TouchableOpacity
            style={styles.sectionHeader}
            onPress={() => setShowAlternatives(!showAlternatives)}
          >
            <Text style={styles.sectionTitle}>Alternative Safer Routes</Text>
            <Text style={styles.expandIcon}>{showAlternatives ? '▼' : '▶'}</Text>
          </TouchableOpacity>

          {showAlternatives && (
            <View style={styles.alternativesContainer}>
              <Text style={styles.recommendationText}>
                {alternativeRoutes.recommendation}
              </Text>

              {/* Direct Route */}
              <View style={styles.routeCard}>
                <View style={styles.routeHeader}>
                  <Text style={styles.routeName}>
                    {alternativeRoutes.direct_route.route_name}
                  </Text>
                  <View
                    style={[
                      styles.routeScoreBadge,
                      {
                        backgroundColor: getRiskColor(
                          getScoreRiskLevel(alternativeRoutes.direct_route.safety_score)
                        ),
                      },
                    ]}
                  >
                    <Text style={styles.routeScoreText}>
                      {alternativeRoutes.direct_route.safety_score}
                    </Text>
                  </View>
                </View>
                <View style={styles.routeStats}>
                  <Text style={styles.routeStat}>
                    Incidents: {alternativeRoutes.direct_route.total_incidents}
                  </Text>
                  <Text style={styles.routeStat}>
                    Zones: {alternativeRoutes.direct_route.total_zones}
                  </Text>
                  <Text style={styles.routeStat}>Detour: 0 km</Text>
                </View>
              </View>

              {/* Alternative Routes */}
              {alternativeRoutes.alternative_routes.map((route, index) => (
                <View key={index} style={styles.routeCard}>
                  <View style={styles.routeHeader}>
                    <Text style={styles.routeName}>{route.route_name}</Text>
                    <View
                      style={[
                        styles.routeScoreBadge,
                        {
                          backgroundColor: getRiskColor(
                            getScoreRiskLevel(route.safety_score)
                          ),
                        },
                      ]}
                    >
                      <Text style={styles.routeScoreText}>{route.safety_score}</Text>
                    </View>
                  </View>
                  <View style={styles.routeStats}>
                    <Text style={styles.routeStat}>
                      Incidents: {route.total_incidents}
                    </Text>
                    <Text style={styles.routeStat}>Zones: {route.total_zones}</Text>
                    <Text style={styles.routeStat}>
                      Detour: +{route.estimated_detour_km} km
                    </Text>
                  </View>
                  {route.safety_score >
                    alternativeRoutes.direct_route.safety_score + 10 && (
                    <View style={styles.recommendedBadge}>
                      <Text style={styles.recommendedText}>✓ Recommended</Text>
                    </View>
                  )}
                  <TouchableOpacity
                    style={styles.navigateButton}
                    onPress={() => openNavigationForRoute(route.waypoints)}
                  >
                    <Text style={styles.navigateButtonText}>
                      🗺 Navigate This Route
                    </Text>
                  </TouchableOpacity>
                </View>
              ))}
            </View>
          )}
        </View>
      )}

      {/* Real-time Updates */}
      {isJourneyActive && realtimeUpdates && (
        <View style={styles.card}>
          <Text style={styles.sectionTitle}>🔴 Live Updates</Text>

          {/* Alerts */}
          {realtimeUpdates.alerts && realtimeUpdates.alerts.length > 0 && (
            <View style={styles.alertsContainer}>
              {realtimeUpdates.alerts.map((alert, index) => (
                <View
                  key={index}
                  style={[
                    styles.alertItem,
                    alert.includes('⚠️') && styles.criticalAlert,
                  ]}
                >
                  <Text style={styles.alertText}>{alert}</Text>
                </View>
              ))}
            </View>
          )}

          {/* Recent Incidents */}
          {realtimeUpdates.recent_incidents &&
            realtimeUpdates.recent_incidents.length > 0 && (
              <View style={styles.section}>
                <Text style={styles.subsectionTitle}>
                  Recent Incidents (Last 10 min)
                </Text>
                {realtimeUpdates.recent_incidents.map((incident, index) => (
                  <View key={index} style={styles.recentIncidentItem}>
                    <Text style={styles.incidentType}>
                      {incident.type === 'hijacking' ? '🚗' : incident.type === 'mugging' ? '👤' : '🚧'}
                    </Text>
                    <View style={styles.incidentDetails}>
                      <Text style={styles.incidentTypeText}>
                        {incident.type.charAt(0).toUpperCase() + incident.type.slice(1)}
                      </Text>
                      <Text style={styles.incidentDistance}>
                        {(incident.distance_meters / 1000).toFixed(1)} km away • {incident.minutes_ago} min ago
                      </Text>
                    </View>
                  </View>
                ))}
              </View>
            )}

          {/* Approaching Zones */}
          {realtimeUpdates.approaching_zones &&
            realtimeUpdates.approaching_zones.length > 0 && (
              <View style={styles.section}>
                <Text style={styles.subsectionTitle}>Approaching Hotspot Zones</Text>
                {realtimeUpdates.approaching_zones.map((zone, index) => (
                  <View key={index} style={styles.approachingZoneItem}>
                    <View
                      style={[
                        styles.zoneRiskIndicator,
                        { backgroundColor: getRiskColor(zone.risk_level) },
                      ]}
                    />
                    <View style={styles.zoneDetails}>
                      <Text style={styles.zoneType}>
                        {zone.type.charAt(0).toUpperCase() + zone.type.slice(1)} Zone
                      </Text>
                      <Text style={styles.zoneDistance}>
                        {(zone.distance_meters / 1000).toFixed(1)} km ahead • {zone.risk_level.toUpperCase()} risk
                      </Text>
                    </View>
                  </View>
                ))}
              </View>
            )}

          {/* Remaining Route Score */}
          <View style={styles.remainingRouteCard}>
            <Text style={styles.remainingRouteLabel}>Remaining Route Safety</Text>
            <Text
              style={[
                styles.remainingRouteScore,
                {
                  color: getRiskColor(
                    realtimeUpdates.remaining_route.risk_level
                  ),
                },
              ]}
            >
              {realtimeUpdates.remaining_route.safety_score}/100
            </Text>
          </View>
        </View>
      )}
    </ScrollView>
  );
};

const getScoreRiskLevel = (score) => {
  if (score >= 80) return 'safe';
  if (score >= 60) return 'moderate';
  if (score >= 40) return 'caution';
  return 'dangerous';
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F8F9FA',
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#F8F9FA',
  },
  loadingText: {
    marginTop: 12,
    fontSize: 16,
    color: '#6C757D',
  },
  header: {
    padding: 20,
    backgroundColor: '#fff',
    borderBottomWidth: 1,
    borderBottomColor: '#E9ECEF',
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#1A1A1A',
    marginBottom: 4,
  },
  subtitle: {
    fontSize: 14,
    color: '#6C757D',
  },
  card: {
    backgroundColor: '#fff',
    margin: 16,
    padding: 16,
    borderRadius: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  label: {
    fontSize: 14,
    fontWeight: '600',
    color: '#6C757D',
    marginBottom: 8,
  },
  locationDisplay: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 12,
    backgroundColor: '#F8F9FA',
    borderRadius: 8,
  },
  locationIcon: {
    fontSize: 20,
    marginRight: 8,
  },
  locationText: {
    fontSize: 14,
    color: '#495057',
    flex: 1,
  },
  inputContainer: {
    flexDirection: 'row',
    marginBottom: 12,
  },
  input: {
    flex: 1,
    height: 48,
    borderWidth: 1,
    borderColor: '#CED4DA',
    borderRadius: 8,
    paddingHorizontal: 16,
    fontSize: 16,
    backgroundColor: '#fff',
  },
  searchButton: {
    marginLeft: 8,
    paddingHorizontal: 20,
    backgroundColor: '#E63946',
    borderRadius: 8,
    justifyContent: 'center',
    alignItems: 'center',
  },
  searchButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  analyzeButton: {
    marginHorizontal: 16,
    marginBottom: 16,
    padding: 16,
    backgroundColor: '#E63946',
    borderRadius: 12,
    alignItems: 'center',
  },
  analyzeButtonText: {
    color: '#fff',
    fontSize: 18,
    fontWeight: 'bold',
  },
  reportCard: {
    backgroundColor: '#fff',
    margin: 16,
    padding: 20,
    borderRadius: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  reportHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 20,
  },
  reportTitle: {
    fontSize: 22,
    fontWeight: 'bold',
    color: '#1A1A1A',
  },
  riskBadge: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 20,
  },
  riskBadgeText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: 'bold',
  },
  scoreContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 16,
    backgroundColor: '#F8F9FA',
    borderRadius: 8,
    marginBottom: 20,
  },
  scoreLabel: {
    fontSize: 18,
    fontWeight: '600',
    color: '#495057',
  },
  scoreValue: {
    fontSize: 32,
    fontWeight: 'bold',
  },
  section: {
    marginBottom: 20,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#1A1A1A',
    marginBottom: 12,
  },
  statsGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    marginHorizontal: -8,
  },
  statItem: {
    width: '50%',
    padding: 8,
    alignItems: 'center',
  },
  statValue: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#1A1A1A',
  },
  statLabel: {
    fontSize: 14,
    color: '#6C757D',
    marginTop: 4,
  },
  recommendationItem: {
    flexDirection: 'row',
    marginBottom: 12,
  },
  recommendationBullet: {
    fontSize: 18,
    color: '#E63946',
    marginRight: 8,
    fontWeight: 'bold',
  },
  recommendationText: {
    flex: 1,
    fontSize: 16,
    color: '#495057',
    lineHeight: 22,
  },
  sectionHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 12,
  },
  expandIcon: {
    fontSize: 16,
    color: '#6C757D',
  },
  segmentsContainer: {
    marginTop: 8,
  },
  segmentCard: {
    backgroundColor: '#F8F9FA',
    padding: 12,
    borderRadius: 8,
    marginBottom: 8,
  },
  segmentHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  segmentNumber: {
    fontSize: 16,
    fontWeight: '600',
    color: '#1A1A1A',
  },
  segmentRiskBadge: {
    paddingHorizontal: 12,
    paddingVertical: 4,
    borderRadius: 12,
  },
  segmentRiskText: {
    color: '#fff',
    fontSize: 12,
    fontWeight: 'bold',
  },
  segmentStats: {
    flexDirection: 'row',
    flexWrap: 'wrap',
  },
  segmentStat: {
    fontSize: 14,
    color: '#495057',
    marginRight: 16,
  },
  startJourneyButton: {
    backgroundColor: '#28A745',
    padding: 16,
    borderRadius: 12,
    alignItems: 'center',
  },
  startJourneyText: {
    color: '#fff',
    fontSize: 18,
    fontWeight: 'bold',
  },
  stopJourneyButton: {
    backgroundColor: '#DC3545',
    padding: 16,
    borderRadius: 12,
    alignItems: 'center',
  },
  stopJourneyText: {
    color: '#fff',
    fontSize: 18,
    fontWeight: 'bold',
  },
  alternativesContainer: {
    marginTop: 12,
  },
  routeCard: {
    backgroundColor: '#F8F9FA',
    padding: 16,
    borderRadius: 8,
    marginTop: 12,
  },
  routeHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  routeName: {
    fontSize: 16,
    fontWeight: '600',
    color: '#1A1A1A',
  },
  routeScoreBadge: {
    width: 48,
    height: 48,
    borderRadius: 24,
    justifyContent: 'center',
    alignItems: 'center',
  },
  routeScoreText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: 'bold',
  },
  routeStats: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  routeStat: {
    fontSize: 14,
    color: '#6C757D',
  },
  recommendedBadge: {
    marginTop: 8,
    backgroundColor: '#28A745',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 12,
    alignSelf: 'flex-start',
  },
  recommendedText: {
    color: '#fff',
    fontSize: 12,
    fontWeight: 'bold',
  },
  alertsContainer: {
    marginBottom: 16,
  },
  alertItem: {
    backgroundColor: '#FFF3CD',
    padding: 12,
    borderRadius: 8,
    marginBottom: 8,
    borderLeftWidth: 4,
    borderLeftColor: '#FFC107',
  },
  criticalAlert: {
    backgroundColor: '#F8D7DA',
    borderLeftColor: '#DC3545',
  },
  alertText: {
    fontSize: 14,
    color: '#1A1A1A',
    fontWeight: '500',
  },
  subsectionTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#1A1A1A',
    marginBottom: 8,
  },
  recentIncidentItem: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 12,
    backgroundColor: '#F8F9FA',
    borderRadius: 8,
    marginBottom: 8,
  },
  incidentType: {
    fontSize: 24,
    marginRight: 12,
  },
  incidentDetails: {
    flex: 1,
  },
  incidentTypeText: {
    fontSize: 16,
    fontWeight: '600',
    color: '#1A1A1A',
  },
  incidentDistance: {
    fontSize: 14,
    color: '#6C757D',
    marginTop: 2,
  },
  approachingZoneItem: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 12,
    backgroundColor: '#F8F9FA',
    borderRadius: 8,
    marginBottom: 8,
  },
  zoneRiskIndicator: {
    width: 8,
    height: 40,
    borderRadius: 4,
    marginRight: 12,
  },
  zoneDetails: {
    flex: 1,
  },
  zoneType: {
    fontSize: 16,
    fontWeight: '600',
    color: '#1A1A1A',
  },
  zoneDistance: {
    fontSize: 14,
    color: '#6C757D',
    marginTop: 2,
  },
  remainingRouteCard: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 16,
    backgroundColor: '#F8F9FA',
    borderRadius: 8,
    marginTop: 12,
  },
  remainingRouteLabel: {
    fontSize: 16,
    fontWeight: '600',
    color: '#495057',
  },
  remainingRouteScore: {
    fontSize: 28,
    fontWeight: 'bold',
  },
  navigateButton: {
    marginTop: 12,
    backgroundColor: '#2196F3',
    padding: 12,
    borderRadius: 8,
    alignItems: 'center',
  },
  navigateButtonText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '600',
  },
});

export default TravelModeScreen;
