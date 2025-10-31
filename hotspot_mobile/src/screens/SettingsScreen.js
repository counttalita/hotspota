import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Switch,
  TouchableOpacity,
  ActivityIndicator,
  Alert,
} from 'react-native';
import Slider from '@react-native-community/slider';
import notificationService from '../services/notificationService';

const SettingsScreen = () => {
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [preferences, setPreferences] = useState({
    alert_radius: 2000,
    notification_config: {
      enabled_types: {
        hijacking: true,
        mugging: true,
        accident: true,
      },
      hotspot_zone_alerts: true,
    },
    is_premium: false,
  });

  useEffect(() => {
    loadPreferences();
  }, []);

  const loadPreferences = async () => {
    try {
      const result = await notificationService.getPreferences();
      if (result.success) {
        setPreferences(result.data);
      } else {
        Alert.alert('Error', 'Failed to load preferences');
      }
    } catch (error) {
      console.error('Error loading preferences:', error);
      Alert.alert('Error', 'Failed to load preferences');
    } finally {
      setLoading(false);
    }
  };

  const savePreferences = async () => {
    setSaving(true);
    try {
      const result = await notificationService.updatePreferences(preferences);
      if (result.success) {
        Alert.alert('Success', 'Preferences saved successfully');
      } else {
        Alert.alert('Error', result.error || 'Failed to save preferences');
      }
    } catch (error) {
      console.error('Error saving preferences:', error);
      Alert.alert('Error', 'Failed to save preferences');
    } finally {
      setSaving(false);
    }
  };

  const toggleIncidentType = (type) => {
    setPreferences((prev) => ({
      ...prev,
      notification_config: {
        ...prev.notification_config,
        enabled_types: {
          ...prev.notification_config.enabled_types,
          [type]: !prev.notification_config.enabled_types[type],
        },
      },
    }));
  };

  const toggleHotspotZoneAlerts = () => {
    setPreferences((prev) => ({
      ...prev,
      notification_config: {
        ...prev.notification_config,
        hotspot_zone_alerts: !prev.notification_config.hotspot_zone_alerts,
      },
    }));
  };

  const updateAlertRadius = (value) => {
    setPreferences((prev) => ({
      ...prev,
      alert_radius: Math.round(value),
    }));
  };

  if (loading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color="#007AFF" />
      </View>
    );
  }

  const maxRadius = preferences.is_premium ? 10000 : 2000;
  const radiusKm = (preferences.alert_radius / 1000).toFixed(1);

  return (
    <ScrollView style={styles.container}>
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Notification Preferences</Text>
        <Text style={styles.sectionDescription}>
          Choose which types of incidents you want to be notified about
        </Text>

        <View style={styles.settingRow}>
          <View style={styles.settingInfo}>
            <Text style={styles.settingLabel}>🚗 Hijacking Alerts</Text>
            <Text style={styles.settingDescription}>
              Get notified about hijacking incidents
            </Text>
          </View>
          <Switch
            value={preferences.notification_config.enabled_types.hijacking}
            onValueChange={() => toggleIncidentType('hijacking')}
            trackColor={{ false: '#D1D5DB', true: '#EF4444' }}
            thumbColor="#FFFFFF"
          />
        </View>

        <View style={styles.settingRow}>
          <View style={styles.settingInfo}>
            <Text style={styles.settingLabel}>👤 Mugging Alerts</Text>
            <Text style={styles.settingDescription}>
              Get notified about mugging incidents
            </Text>
          </View>
          <Switch
            value={preferences.notification_config.enabled_types.mugging}
            onValueChange={() => toggleIncidentType('mugging')}
            trackColor={{ false: '#D1D5DB', true: '#F97316' }}
            thumbColor="#FFFFFF"
          />
        </View>

        <View style={styles.settingRow}>
          <View style={styles.settingInfo}>
            <Text style={styles.settingLabel}>🚑 Accident Alerts</Text>
            <Text style={styles.settingDescription}>
              Get notified about accident incidents
            </Text>
          </View>
          <Switch
            value={preferences.notification_config.enabled_types.accident}
            onValueChange={() => toggleIncidentType('accident')}
            trackColor={{ false: '#D1D5DB', true: '#3B82F6' }}
            thumbColor="#FFFFFF"
          />
        </View>

        <View style={styles.settingRow}>
          <View style={styles.settingInfo}>
            <Text style={styles.settingLabel}>🚨 Hotspot Zone Alerts</Text>
            <Text style={styles.settingDescription}>
              Get notified when entering high-risk areas
            </Text>
          </View>
          <Switch
            value={preferences.notification_config.hotspot_zone_alerts}
            onValueChange={toggleHotspotZoneAlerts}
            trackColor={{ false: '#D1D5DB', true: '#EF4444' }}
            thumbColor="#FFFFFF"
          />
        </View>
      </View>

      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Alert Radius</Text>
        <Text style={styles.sectionDescription}>
          Set how far away incidents should be to trigger notifications
        </Text>

        <View style={styles.radiusContainer}>
          <Text style={styles.radiusValue}>{radiusKm} km</Text>
          <Slider
            style={styles.slider}
            minimumValue={1000}
            maximumValue={maxRadius}
            step={500}
            value={preferences.alert_radius}
            onValueChange={updateAlertRadius}
            minimumTrackTintColor="#007AFF"
            maximumTrackTintColor="#D1D5DB"
            thumbTintColor="#007AFF"
          />
          <View style={styles.radiusLabels}>
            <Text style={styles.radiusLabel}>1 km</Text>
            <Text style={styles.radiusLabel}>
              {maxRadius / 1000} km {!preferences.is_premium && '(Max for Free)'}
            </Text>
          </View>
        </View>

        {!preferences.is_premium && (
          <View style={styles.premiumBanner}>
            <Text style={styles.premiumText}>
              ⭐ Upgrade to Premium to extend your alert radius up to 10 km
            </Text>
          </View>
        )}
      </View>

      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Account</Text>
        <View style={styles.accountInfo}>
          <Text style={styles.accountLabel}>Subscription Status</Text>
          <Text style={[styles.accountValue, preferences.is_premium && styles.premiumValue]}>
            {preferences.is_premium ? '⭐ Premium' : 'Free'}
          </Text>
        </View>
      </View>

      <TouchableOpacity
        style={[styles.saveButton, saving && styles.saveButtonDisabled]}
        onPress={savePreferences}
        disabled={saving}
      >
        {saving ? (
          <ActivityIndicator color="#FFFFFF" />
        ) : (
          <Text style={styles.saveButtonText}>Save Preferences</Text>
        )}
      </TouchableOpacity>

      <View style={styles.bottomPadding} />
    </ScrollView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F9FAFB',
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#F9FAFB',
  },
  section: {
    backgroundColor: '#FFFFFF',
    marginTop: 16,
    paddingHorizontal: 16,
    paddingVertical: 20,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: '700',
    color: '#1F2937',
    marginBottom: 8,
  },
  sectionDescription: {
    fontSize: 14,
    color: '#6B7280',
    marginBottom: 16,
  },
  settingRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#F3F4F6',
  },
  settingInfo: {
    flex: 1,
    marginRight: 16,
  },
  settingLabel: {
    fontSize: 16,
    fontWeight: '600',
    color: '#1F2937',
    marginBottom: 4,
  },
  settingDescription: {
    fontSize: 13,
    color: '#9CA3AF',
  },
  radiusContainer: {
    marginTop: 8,
  },
  radiusValue: {
    fontSize: 24,
    fontWeight: '700',
    color: '#007AFF',
    textAlign: 'center',
    marginBottom: 16,
  },
  slider: {
    width: '100%',
    height: 40,
  },
  radiusLabels: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: 8,
  },
  radiusLabel: {
    fontSize: 12,
    color: '#9CA3AF',
  },
  premiumBanner: {
    backgroundColor: '#FEF3C7',
    borderRadius: 8,
    padding: 12,
    marginTop: 16,
  },
  premiumText: {
    fontSize: 13,
    color: '#92400E',
    textAlign: 'center',
  },
  accountInfo: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 12,
  },
  accountLabel: {
    fontSize: 16,
    color: '#6B7280',
  },
  accountValue: {
    fontSize: 16,
    fontWeight: '600',
    color: '#1F2937',
  },
  premiumValue: {
    color: '#F59E0B',
  },
  saveButton: {
    backgroundColor: '#007AFF',
    marginHorizontal: 16,
    marginTop: 24,
    paddingVertical: 16,
    borderRadius: 12,
    alignItems: 'center',
  },
  saveButtonDisabled: {
    opacity: 0.6,
  },
  saveButtonText: {
    fontSize: 16,
    fontWeight: '700',
    color: '#FFFFFF',
  },
  bottomPadding: {
    height: 32,
  },
});

export default SettingsScreen;
