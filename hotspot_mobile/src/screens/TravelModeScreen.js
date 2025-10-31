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
    } catch (error) {
      console.error('Route analysis error:', error);
      Alert.alert('Error', error.message || 'Failed to analyze route');
    } finally {
      setAnalyzing(false);
    }
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
        </View>
      )}
    </ScrollView>
  );
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
});

export default TravelModeScreen;
