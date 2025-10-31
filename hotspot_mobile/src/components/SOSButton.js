import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Alert,
  Modal,
  ActivityIndicator,
  Linking,
} from 'react-native';
import * as Location from 'expo-location';
import * as Haptics from 'expo-haptics';
import emergencyService from '../services/emergencyService';

const SOSButton = ({ user, navigation }) => {
  const [showModal, setShowModal] = useState(false);
  const [sending, setSending] = useState(false);
  const [hasActiveAlert, setHasActiveAlert] = useState(false);
  const [showConfirmation, setShowConfirmation] = useState(false);

  useEffect(() => {
    checkPanicStatus();
  }, []);

  const checkPanicStatus = async () => {
    try {
      const status = await emergencyService.getPanicStatus();
      setHasActiveAlert(status.active);
    } catch (error) {
      console.error('Error checking panic status:', error);
    }
  };

  const handleSOSPress = async () => {
    // Haptic feedback for button press
    await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Heavy);

    // Check if user has emergency contacts
    try {
      const contacts = await emergencyService.getEmergencyContacts();
      
      if (contacts.length === 0) {
        Alert.alert(
          'No Emergency Contacts',
          'Please add emergency contacts in your settings before using the panic button.',
          [
            { text: 'Cancel', style: 'cancel' },
            { 
              text: 'Add Contacts', 
              onPress: () => navigation?.navigate('EmergencyContacts')
            },
          ]
        );
        return;
      }

      // Check if there's already an active alert
      if (hasActiveAlert) {
        Alert.alert(
          'Active Alert',
          'You already have an active panic alert. Would you like to cancel it?',
          [
            { text: 'No', style: 'cancel' },
            { text: 'Cancel Alert', onPress: handleCancelAlert },
          ]
        );
        return;
      }

      setShowModal(true);
    } catch (error) {
      console.error('Error checking contacts:', error);
      Alert.alert('Error', 'Failed to check emergency contacts. Please try again.');
    }
  };

  const sendSOSAlert = async () => {
    try {
      setSending(true);

      // Get current location
      const { status } = await Location.requestForegroundPermissionsAsync();
      if (status !== 'granted') {
        Alert.alert('Permission Denied', 'Location permission is required for panic button');
        setSending(false);
        return;
      }

      const location = await Location.getCurrentPositionAsync({
        accuracy: Location.Accuracy.High,
      });
      const { latitude, longitude } = location.coords;

      // Trigger panic button on backend (sends SMS and push notifications)
      await emergencyService.triggerPanicButton(latitude, longitude);

      // Strong haptic feedback for confirmation
      await Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);

      setShowModal(false);
      setShowConfirmation(true);
      setHasActiveAlert(true);

      // Auto-hide confirmation after 3 seconds
      setTimeout(() => {
        setShowConfirmation(false);
      }, 3000);
    } catch (error) {
      console.error('Panic button error:', error);
      
      let errorMessage = 'Failed to send panic alert. Please try again.';
      if (error.response?.data?.error) {
        errorMessage = error.response.data.error;
      }
      
      Alert.alert('Error', errorMessage);
    } finally {
      setSending(false);
    }
  };

  const handleCancelAlert = async () => {
    try {
      await emergencyService.resolvePanic('Cancelled by user');
      setHasActiveAlert(false);
      Alert.alert('Alert Cancelled', 'Your panic alert has been cancelled.');
    } catch (error) {
      console.error('Error cancelling alert:', error);
      Alert.alert('Error', 'Failed to cancel alert. Please try again.');
    }
  };

  const handleCallEmergency = () => {
    Alert.alert(
      'Call Emergency Services',
      'Would you like to call emergency services?',
      [
        { text: 'Cancel', style: 'cancel' },
        { 
          text: 'Call 911', 
          onPress: () => Linking.openURL('tel:911')
        },
      ]
    );
  };

  return (
    <>
      <TouchableOpacity
        style={[
          styles.sosButton,
          hasActiveAlert && styles.sosButtonActive
        ]}
        onPress={handleSOSPress}
        activeOpacity={0.8}
      >
        <Text style={styles.sosText}>
          {hasActiveAlert ? '⚠️' : 'SOS'}
        </Text>
      </TouchableOpacity>

      {/* Panic Alert Confirmation Modal */}
      <Modal
        visible={showModal}
        transparent
        animationType="fade"
        onRequestClose={() => !sending && setShowModal(false)}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <Text style={styles.modalTitle}>🚨 Send Panic Alert?</Text>
            <Text style={styles.modalMessage}>
              This will immediately send your current location to all your emergency contacts via SMS and push notification.
            </Text>
            <Text style={styles.modalWarning}>
              Use only in real emergencies!
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
                  <Text style={styles.confirmButtonText}>Send Alert</Text>
                )}
              </TouchableOpacity>
            </View>

            <TouchableOpacity
              style={styles.emergencyCallButton}
              onPress={handleCallEmergency}
              disabled={sending}
            >
              <Text style={styles.emergencyCallText}>📞 Call Emergency Services</Text>
            </TouchableOpacity>
          </View>
        </View>
      </Modal>

      {/* Success Confirmation Modal */}
      <Modal
        visible={showConfirmation}
        transparent
        animationType="fade"
      >
        <View style={styles.modalOverlay}>
          <View style={styles.confirmationContent}>
            <Text style={styles.confirmationIcon}>✓</Text>
            <Text style={styles.confirmationTitle}>Help is on the way</Text>
            <Text style={styles.confirmationMessage}>
              Your emergency contacts have been notified with your location.
            </Text>
            <TouchableOpacity
              style={styles.confirmationButton}
              onPress={() => setShowConfirmation(false)}
            >
              <Text style={styles.confirmationButtonText}>OK</Text>
            </TouchableOpacity>
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
  sosButtonActive: {
    backgroundColor: '#FFC107',
    borderColor: '#FF9800',
  },
  sosText: {
    color: '#fff',
    fontSize: 18,
    fontWeight: 'bold',
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.6)',
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
    fontSize: 24,
    fontWeight: 'bold',
    color: '#DC3545',
    marginBottom: 12,
    textAlign: 'center',
  },
  modalMessage: {
    fontSize: 16,
    color: '#495057',
    marginBottom: 12,
    textAlign: 'center',
    lineHeight: 22,
  },
  modalWarning: {
    fontSize: 14,
    color: '#DC3545',
    marginBottom: 24,
    textAlign: 'center',
    fontWeight: '600',
  },
  modalButtons: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 16,
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
  emergencyCallButton: {
    padding: 12,
    borderRadius: 8,
    backgroundColor: '#007BFF',
    alignItems: 'center',
  },
  emergencyCallText: {
    color: '#fff',
    fontSize: 15,
    fontWeight: '600',
  },
  confirmationContent: {
    backgroundColor: '#fff',
    borderRadius: 16,
    padding: 32,
    width: '80%',
    maxWidth: 350,
    alignItems: 'center',
  },
  confirmationIcon: {
    fontSize: 64,
    color: '#28A745',
    marginBottom: 16,
  },
  confirmationTitle: {
    fontSize: 22,
    fontWeight: 'bold',
    color: '#1A1A1A',
    marginBottom: 12,
    textAlign: 'center',
  },
  confirmationMessage: {
    fontSize: 16,
    color: '#495057',
    marginBottom: 24,
    textAlign: 'center',
    lineHeight: 22,
  },
  confirmationButton: {
    backgroundColor: '#28A745',
    paddingHorizontal: 32,
    paddingVertical: 12,
    borderRadius: 8,
  },
  confirmationButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: 'bold',
  },
});

export default SOSButton;
