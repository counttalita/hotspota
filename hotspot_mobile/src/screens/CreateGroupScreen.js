import React, { useState } from 'react';
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  ScrollView,
  Alert,
  ActivityIndicator,
} from 'react-native';
import * as Location from 'expo-location';
import { communityService } from '../services/communityService';

const CreateGroupScreen = ({ navigation }) => {
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [locationName, setLocationName] = useState('');
  const [useCurrentLocation, setUseCurrentLocation] = useState(false);
  const [loading, setLoading] = useState(false);

  const handleGetCurrentLocation = async () => {
    try {
      setLoading(true);
      const { status } = await Location.requestForegroundPermissionsAsync();
      if (status !== 'granted') {
        Alert.alert('Permission Denied', 'Location permission is required');
        return;
      }

      const location = await Location.getCurrentPositionAsync({});
      const address = await Location.reverseGeocodeAsync({
        latitude: location.coords.latitude,
        longitude: location.coords.longitude,
      });

      if (address.length > 0) {
        const addr = address[0];
        const locationStr = [addr.street, addr.city, addr.region]
          .filter(Boolean)
          .join(', ');
        setLocationName(locationStr);
      }

      setUseCurrentLocation(true);
    } catch (error) {
      console.error('Error getting location:', error);
      Alert.alert('Error', 'Failed to get current location');
    } finally {
      setLoading(false);
    }
  };

  const handleCreateGroup = async () => {
    if (!name.trim()) {
      Alert.alert('Validation Error', 'Group name is required');
      return;
    }

    if (name.length < 3) {
      Alert.alert('Validation Error', 'Group name must be at least 3 characters');
      return;
    }

    try {
      setLoading(true);

      const groupData = {
        name: name.trim(),
        description: description.trim() || null,
        location_name: locationName.trim() || null,
        is_public: true,
      };

      // Add location coordinates if using current location
      if (useCurrentLocation) {
        const location = await Location.getCurrentPositionAsync({});
        groupData.center_latitude = location.coords.latitude;
        groupData.center_longitude = location.coords.longitude;
        groupData.radius_meters = 5000; // Default 5km radius
      }

      const newGroup = await communityService.createGroup(groupData);
      Alert.alert('Success', 'Group created successfully', [
        {
          text: 'OK',
          onPress: () => navigation.navigate('GroupDetail', { groupId: newGroup.id }),
        },
      ]);
    } catch (error) {
      console.error('Error creating group:', error);
      Alert.alert('Error', 'Failed to create group');
    } finally {
      setLoading(false);
    }
  };

  return (
    <ScrollView style={styles.container}>
      <View style={styles.content}>
        <Text style={styles.title}>Create Community Group</Text>
        <Text style={styles.subtitle}>
          Create a group to share safety information with your neighborhood
        </Text>

        <View style={styles.formGroup}>
          <Text style={styles.label}>Group Name *</Text>
          <TextInput
            style={styles.input}
            placeholder="e.g., Sandton Neighborhood Watch"
            value={name}
            onChangeText={setName}
            maxLength={100}
          />
          <Text style={styles.helperText}>{name.length}/100 characters</Text>
        </View>

        <View style={styles.formGroup}>
          <Text style={styles.label}>Description</Text>
          <TextInput
            style={[styles.input, styles.textArea]}
            placeholder="Describe your community group..."
            value={description}
            onChangeText={setDescription}
            multiline
            numberOfLines={4}
            maxLength={500}
          />
          <Text style={styles.helperText}>{description.length}/500 characters</Text>
        </View>

        <View style={styles.formGroup}>
          <Text style={styles.label}>Location</Text>
          <TextInput
            style={styles.input}
            placeholder="e.g., Sandton, Johannesburg"
            value={locationName}
            onChangeText={setLocationName}
            maxLength={200}
          />
          <TouchableOpacity
            style={styles.locationButton}
            onPress={handleGetCurrentLocation}
            disabled={loading}
          >
            <Text style={styles.locationButtonText}>
              📍 Use Current Location
            </Text>
          </TouchableOpacity>
        </View>

        <View style={styles.infoBox}>
          <Text style={styles.infoTitle}>ℹ️ About Group Location</Text>
          <Text style={styles.infoText}>
            If you set a location, incidents within 5km of this location will automatically
            appear in your group feed. Members will also receive notifications for nearby
            incidents.
          </Text>
        </View>

        <TouchableOpacity
          style={[styles.createButton, loading && styles.createButtonDisabled]}
          onPress={handleCreateGroup}
          disabled={loading}
        >
          {loading ? (
            <ActivityIndicator color="#FFFFFF" />
          ) : (
            <Text style={styles.createButtonText}>Create Group</Text>
          )}
        </TouchableOpacity>

        <TouchableOpacity
          style={styles.cancelButton}
          onPress={() => navigation.goBack()}
          disabled={loading}
        >
          <Text style={styles.cancelButtonText}>Cancel</Text>
        </TouchableOpacity>
      </View>
    </ScrollView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F7FAFC',
  },
  content: {
    padding: 16,
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#1A202C',
    marginBottom: 8,
  },
  subtitle: {
    fontSize: 16,
    color: '#718096',
    marginBottom: 24,
  },
  formGroup: {
    marginBottom: 24,
  },
  label: {
    fontSize: 16,
    fontWeight: '600',
    color: '#1A202C',
    marginBottom: 8,
  },
  input: {
    backgroundColor: '#FFFFFF',
    borderWidth: 1,
    borderColor: '#E2E8F0',
    borderRadius: 8,
    padding: 12,
    fontSize: 16,
    color: '#1A202C',
  },
  textArea: {
    height: 100,
    textAlignVertical: 'top',
  },
  helperText: {
    fontSize: 12,
    color: '#718096',
    marginTop: 4,
    textAlign: 'right',
  },
  locationButton: {
    backgroundColor: '#EDF2F7',
    paddingVertical: 12,
    paddingHorizontal: 16,
    borderRadius: 8,
    marginTop: 8,
    alignItems: 'center',
  },
  locationButtonText: {
    fontSize: 16,
    color: '#4A5568',
    fontWeight: '500',
  },
  infoBox: {
    backgroundColor: '#EBF8FF',
    borderRadius: 8,
    padding: 16,
    marginBottom: 24,
  },
  infoTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#2C5282',
    marginBottom: 8,
  },
  infoText: {
    fontSize: 14,
    color: '#2C5282',
    lineHeight: 20,
  },
  createButton: {
    backgroundColor: '#E53E3E',
    paddingVertical: 16,
    borderRadius: 8,
    alignItems: 'center',
    marginBottom: 12,
  },
  createButtonDisabled: {
    opacity: 0.6,
  },
  createButtonText: {
    color: '#FFFFFF',
    fontSize: 18,
    fontWeight: '600',
  },
  cancelButton: {
    paddingVertical: 16,
    alignItems: 'center',
  },
  cancelButtonText: {
    color: '#718096',
    fontSize: 16,
    fontWeight: '500',
  },
});

export default CreateGroupScreen;
