import React, { useMemo } from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { Marker } from 'react-map-gl';

/**
 * Clusters nearby markers to improve map performance.
 * Uses a simple grid-based clustering algorithm.
 */

const CLUSTER_RADIUS = 50; // pixels

export const useMarkerClustering = (incidents, zoom) => {
  return useMemo(() => {
    if (!incidents || incidents.length === 0) return [];
    
    // Don't cluster at high zoom levels
    if (zoom >= 14) {
      return incidents.map(incident => ({
        type: 'single',
        incident,
        latitude: incident.latitude,
        longitude: incident.longitude
      }));
    }

    const clusters = [];
    const processed = new Set();

    incidents.forEach((incident, index) => {
      if (processed.has(index)) return;

      const cluster = {
        type: 'cluster',
        incidents: [incident],
        latitude: incident.latitude,
        longitude: incident.longitude,
        dominantType: incident.type
      };

      // Find nearby incidents to cluster
      incidents.forEach((other, otherIndex) => {
        if (index === otherIndex || processed.has(otherIndex)) return;

        const distance = calculatePixelDistance(
          incident.latitude,
          incident.longitude,
          other.latitude,
          other.longitude,
          zoom
        );

        if (distance < CLUSTER_RADIUS) {
          cluster.incidents.push(other);
          processed.add(otherIndex);
        }
      });

      processed.add(index);

      // Calculate cluster center
      if (cluster.incidents.length > 1) {
        const avgLat = cluster.incidents.reduce((sum, i) => sum + i.latitude, 0) / cluster.incidents.length;
        const avgLng = cluster.incidents.reduce((sum, i) => sum + i.longitude, 0) / cluster.incidents.length;
        cluster.latitude = avgLat;
        cluster.longitude = avgLng;

        // Determine dominant type
        const typeCounts = {};
        cluster.incidents.forEach(i => {
          typeCounts[i.type] = (typeCounts[i.type] || 0) + 1;
        });
        cluster.dominantType = Object.keys(typeCounts).reduce((a, b) => 
          typeCounts[a] > typeCounts[b] ? a : b
        );
      }

      clusters.push(cluster.incidents.length > 1 ? cluster : {
        type: 'single',
        incident: cluster.incidents[0],
        latitude: cluster.incidents[0].latitude,
        longitude: cluster.incidents[0].longitude
      });
    });

    return clusters;
  }, [incidents, zoom]);
};

// Approximate pixel distance between two coordinates at given zoom level
const calculatePixelDistance = (lat1, lng1, lat2, lng2, zoom) => {
  const scale = 256 * Math.pow(2, zoom);
  const x1 = (lng1 + 180) / 360 * scale;
  const y1 = (1 - Math.log(Math.tan(lat1 * Math.PI / 180) + 1 / Math.cos(lat1 * Math.PI / 180)) / Math.PI) / 2 * scale;
  const x2 = (lng2 + 180) / 360 * scale;
  const y2 = (1 - Math.log(Math.tan(lat2 * Math.PI / 180) + 1 / Math.cos(lat2 * Math.PI / 180)) / Math.PI) / 2 * scale;
  
  return Math.sqrt(Math.pow(x2 - x1, 2) + Math.pow(y2 - y1, 2));
};

export const ClusterMarker = ({ cluster, onPress }) => {
  if (cluster.type === 'single') {
    return (
      <Marker
        latitude={cluster.latitude}
        longitude={cluster.longitude}
        anchor="bottom"
        onPress={() => onPress(cluster.incident)}
      >
        <View style={[styles.marker, styles[`marker${capitalize(cluster.incident.type)}`]]}>
          <Text style={styles.markerIcon}>{getIncidentIcon(cluster.incident.type)}</Text>
        </View>
      </Marker>
    );
  }

  return (
    <Marker
      latitude={cluster.latitude}
      longitude={cluster.longitude}
      anchor="center"
      onPress={() => onPress(cluster.incidents)}
    >
      <View style={[styles.clusterMarker, styles[`cluster${capitalize(cluster.dominantType)}`]]}>
        <Text style={styles.clusterCount}>{cluster.incidents.length}</Text>
      </View>
    </Marker>
  );
};

const getIncidentIcon = (type) => {
  switch (type) {
    case 'hijacking':
      return '🚗';
    case 'mugging':
      return '👤';
    case 'accident':
      return '⚠️';
    default:
      return '📍';
  }
};

const capitalize = (str) => str.charAt(0).toUpperCase() + str.slice(1);

const styles = StyleSheet.create({
  marker: {
    width: 36,
    height: 36,
    borderRadius: 18,
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 2,
    borderColor: '#fff',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.25,
    shadowRadius: 3.84,
    elevation: 5,
  },
  markerHijacking: {
    backgroundColor: '#EF4444',
  },
  markerMugging: {
    backgroundColor: '#F97316',
  },
  markerAccident: {
    backgroundColor: '#3B82F6',
  },
  markerIcon: {
    fontSize: 18,
  },
  clusterMarker: {
    width: 48,
    height: 48,
    borderRadius: 24,
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 3,
    borderColor: '#fff',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.3,
    shadowRadius: 4,
    elevation: 6,
  },
  clusterHijacking: {
    backgroundColor: '#DC2626',
  },
  clusterMugging: {
    backgroundColor: '#EA580C',
  },
  clusterAccident: {
    backgroundColor: '#2563EB',
  },
  clusterCount: {
    color: '#fff',
    fontSize: 16,
    fontWeight: 'bold',
  },
});
