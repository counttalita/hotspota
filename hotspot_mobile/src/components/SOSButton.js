import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Alert,
  Modal,
  ActivityIndicator,
} from 'react-native';
import * as Location from 'expo-location';
import * as SMS from 'expo-sms';

const SOSButton = ({ user }) => {
  const [showModal, setShowModal] = useState(false);
  const [sending, setSending] = useState(false);

  const handleSOSPress = () => {
    if (!user?.is_premium) {
      Alert.alert(
        'Premium Feature',
        'SOS button is a premium feature. Upgrade your subscription to access this feature.',
        [
          { text: 'Cancel', style: 'cancel' },
          { text: 'Upgrade', onPress: () => {/* Navigate to subscription */ } },
        ]
      );
      return;
    }

    setShowModal(true);
  };

  const sendSOSAlert = async () => {
    try {
      setSending(true);

      // Get current location
      const { status } = await Location.requestForegroundPermissionsAsync();
      if (status !== 'granted') {
        Alert.alert('Permission Denied', 'Location permission is required for SOS');
        return;
      }

      const location = await Location.getCurrentPositionAsync({});
      const { latitude, longitude } = location.coords;

      // Create Google Maps link
      const mapsLink = `https://maps.google.com/?q=${latitude},${longitude}`;

      // Get emergency contacts from user profile
      // For now, we'll use a placeholder
      const emergencyContacts = user?.emergency_contacts || [];

      if (emergencyContacts.length === 0) {
        Alert.alert(
          'No Emergency Contacts',
          'Please add emergency contacts in your profile settings first.',
          [{ text: 'OK' }]
        );
        setShowModal(false);
        return;
      }

      // Check if SMS is available
      const isAvailable = await SMS.isAvailableAsync();
      if (!isAvailable) {
        Alert.alert('Error', 'SMS is not available on this device');
        return;
      }

      // Send SMS to emergency contacts
      const message = `🚨 EMERGENCY ALERT from ${user.phone_number}\n\nI need help! My current location:\n${mapsLink}\n\nThis is an automated SOS alert from Hotspot Safety App.`;

      await SMS.sendSMSAsync(emergencyContacts, message);

      Alert.alert(
        'SOS Sent',
        'Emergency alert has been sent to your trusted contacts.',
        [{ text: 'OK', onPress: () => setShowModal(false) }]
      );
    } catch (error) {
      console.error('SOS error:', error);
      Alert.alert('Error', 'Failed to send SOS alert. Please try again.');
    } finally {
      setSending(false);
    }
  };

  return (
    <>
      <TouchableOpacity
        style={styles.sosButton}
        onPress={handleSOSPress}
        activeOpacity={0.8}
      >
        <Text style={styles.sosText}>SOS</Text>
      </TouchableOpacity>

      <Modal
        visible={showModal}
        transparent
        animationType="fade"
        onRequestClose={() => setShowModal(false)}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <Text style={styles.modalTitle}>Send SOS Alert?</Text>
            <Text style={styles.modalMessage}>
              This will send your current location to your emergency contacts via SMS.
            </Text>

            <View style={styles.modalButtons}>
              <TouchableOpacity
                style={[styles.modalButton, styles.cancelButton]}
                onPress={() => setShowModal(false)}
                disabled={sending}
              >
                <Text style={styles.cancelButtonText}>Cancel</Text>
              </TouchableOpacity>

              <TouchableOpacity
                style={[styles.modalButton, styles.confirmButton]}
                onPress={sendSOSAlert}
                disabled={sending}
              >
                {sending ? (
                  <ActivityIndicator color="#fff" />
                ) : (
                  <Text style={styles.confirmButtonText}>Send SOS</Text>
                )}
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>
    </>
  );
};

const styles = StyleSheet.create({
  sosButton: {
    position: 'absolute',
    bottom: 100,
    right: 20,
    width: 70,
    height: 70,
    borderRadius: 35,
    backgroundColor: '#DC3545',
    justifyContent: 'center',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 6,
    elevation: 8,
    borderWidth: 3,
    borderColor: '#fff',
  },
  sosText: {
    color: '#fff',
    fontSize: 18,
    fontWeight: 'bold',
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  modalContent: {
    backgroundColor: '#fff',
    borderRadius: 16,
    padding: 24,
    width: '85%',
    maxWidth: 400,
  },
  modalTitle: {
    fontSize: 22,
    fontWeight: 'bold',
    color: '#1A1A1A',
    marginBottom: 12,
    textAlign: 'center',
  },
  modalMessage: {
    fontSize: 16,
    color: '#495057',
    marginBottom: 24,
    textAlign: 'center',
    lineHeight: 22,
  },
  modalButtons: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  modalButton: {
    flex: 1,
    padding: 14,
    borderRadius: 8,
    alignItems: 'center',
  },
  cancelButton: {
    backgroundColor: '#6C757D',
    marginRight: 8,
  },
  confirmButton: {
    backgroundColor: '#DC3545',
    marginLeft: 8,
  },
  cancelButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  confirmButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: 'bold',
  },
});

export default SOSButton;
