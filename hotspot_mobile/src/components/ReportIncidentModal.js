import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  Modal,
  StyleSheet,
  TouchableOpacity,
  TextInput,
  ScrollView,
  Image,
  Alert,
  ActivityIndicator,
} from 'react-native';
import * as Location from 'expo-location';
import * as ImagePicker from 'expo-image-picker';
import * as ImageManipulator from 'expo-image-manipulator';
import NetInfo from '@react-native-community/netinfo';
import { incidentService } from '../services/incidentService';

const INCIDENT_TYPES = [
  { id: 'hijacking', label: 'Hijacking', color: '#EF4444', icon: '🚗' },
  { id: 'mugging', label: 'Mugging', color: '#F97316', icon: '👤' },
  { id: 'accident', label: 'Accident', color: '#3B82F6', icon: '💥' },
];

const ReportIncidentModal = ({ visible, onClose, onReportSuccess }) => {
  const [step, setStep] = useState(1); // 1: type selection, 2: details
  const [selectedType, setSelectedType] = useState(null);
  const [description, setDescription] = useState('');
  const [photo, setPhoto] = useState(null);
  const [location, setLocation] = useState(null);
  const [loading, setLoading] = useState(false);
  const [isOnline, setIsOnline] = useState(true);
  const [validationError, setValidationError] = useState(null);
  const [profanityWarning, setProfanityWarning] = useState(false);
  const [uploadProgress, setUploadProgress] = useState(0);

  useEffect(() => {
    if (visible) {
      captureLocation();
      checkConnectivity();
    }
  }, [visible]);

  const checkConnectivity = async () => {
    const state = await NetInfo.fetch();
    setIsOnline(state.isConnected);
  };

  const captureLocation = async () => {
    try {
      const currentLocation = await Location.getCurrentPositionAsync({
        accuracy: Location.Accuracy.High,
      });
      setLocation({
        latitude: currentLocation.coords.latitude,
        longitude: currentLocation.coords.longitude,
      });
    } catch (error) {
      console.error('Error getting location:', error);
      Alert.alert('Error', 'Failed to get your current location');
    }
  };

  const handleTypeSelect = (type) => {
    setSelectedType(type);
    setStep(2);
  };

  const handleTakePhoto = async () => {
    try {
      const { status } = await ImagePicker.requestCameraPermissionsAsync();
      if (status !== 'granted') {
        Alert.alert('Permission Denied', 'Camera permission is required to take photos');
        return;
      }

      const result = await ImagePicker.launchCameraAsync({
        mediaTypes: ImagePicker.MediaTypeOptions.Images,
        allowsEditing: true,
        aspect: [4, 3],
        quality: 0.8,
      });

      if (!result.canceled) {
        await compressAndSetPhoto(result.assets[0]);
      }
    } catch (error) {
      console.error('Error taking photo:', error);
      Alert.alert('Error', 'Failed to take photo');
    }
  };

  const handlePickPhoto = async () => {
    try {
      const { status } = await ImagePicker.requestMediaLibraryPermissionsAsync();
      if (status !== 'granted') {
        Alert.alert('Permission Denied', 'Photo library permission is required');
        return;
      }

      const result = await ImagePicker.launchImageLibraryAsync({
        mediaTypes: ImagePicker.MediaTypeOptions.Images,
        allowsEditing: true,
        aspect: [4, 3],
        quality: 0.8,
      });

      if (!result.canceled) {
        await compressAndSetPhoto(result.assets[0]);
      }
    } catch (error) {
      console.error('Error picking photo:', error);
      Alert.alert('Error', 'Failed to pick photo');
    }
  };

  const compressAndSetPhoto = async (asset) => {
    try {
      setLoading(true);
      setUploadProgress(0);

      // Compress image to reduce size
      const manipResult = await ImageManipulator.manipulateAsync(
        asset.uri,
        [{ resize: { width: 1024 } }],
        { compress: 0.7, format: ImageManipulator.SaveFormat.JPEG }
      );

      setUploadProgress(50);

      // Validate image size (max 10MB)
      const fileInfo = await fetch(manipResult.uri);
      const blob = await fileInfo.blob();
      const sizeInMB = blob.size / (1024 * 1024);

      if (sizeInMB > 10) {
        Alert.alert('Error', 'Image must be under 10MB. Please choose a smaller image.');
        return;
      }

      setUploadProgress(100);

      setPhoto({
        uri: manipResult.uri,
        type: 'image/jpeg',
        fileName: `incident_${Date.now()}.jpg`,
        size: blob.size,
      });
    } catch (error) {
      console.error('Error compressing photo:', error);
      Alert.alert('Error', 'Failed to process photo');
    } finally {
      setLoading(false);
      setUploadProgress(0);
    }
  };

  const validateDescription = (text) => {
    setDescription(text);
    setValidationError(null);
    setProfanityWarning(false);

    if (text.length > 0 && text.length < 10) {
      setValidationError('Description must be at least 10 characters');
    } else if (text.length > 500) {
      setValidationError('Description must be at most 500 characters');
    }

    // Simple client-side profanity check
    const profanityWords = ['fuck', 'shit', 'damn', 'bitch', 'asshole'];
    const hasProfanity = profanityWords.some(word => 
      text.toLowerCase().includes(word)
    );
    
    if (hasProfanity) {
      setProfanityWarning(true);
    }
  };

  const handleSubmit = async () => {
    if (!selectedType || !location) {
      Alert.alert('Error', 'Please select an incident type and ensure location is available');
      return;
    }

    // Validate description length
    if (description.trim().length > 0 && description.trim().length < 10) {
      Alert.alert('Validation Error', 'Description must be at least 10 characters');
      return;
    }

    if (description.trim().length > 500) {
      Alert.alert('Validation Error', 'Description must be at most 500 characters');
      return;
    }

    setLoading(true);
    setValidationError(null);

    try {
      let photoUrl = null;

      // Upload photo if available and online
      if (photo && isOnline) {
        try {
          setUploadProgress(0);
          const uploadResult = await incidentService.uploadPhoto(photo);
          photoUrl = uploadResult.photo_url;
          setUploadProgress(100);
        } catch (error) {
          console.error('Photo upload failed:', error);
          
          // Check for specific error types
          if (error.response?.status === 422) {
            Alert.alert('Image Rejected', error.response?.data?.error || 'Invalid image');
            setLoading(false);
            return;
          } else if (error.response?.status === 409) {
            Alert.alert('Duplicate Image', 'This image has already been uploaded');
            setLoading(false);
            return;
          } else if (error.response?.status === 429) {
            const retryAfter = error.response?.data?.retry_after || 3600;
            Alert.alert(
              'Rate Limit Exceeded',
              `Too many uploads. Please try again in ${Math.ceil(retryAfter / 60)} minutes.`
            );
            setLoading(false);
            return;
          }
          // Continue without photo if other errors
        }
      }

      const incidentData = {
        type: selectedType.id,
        latitude: location.latitude,
        longitude: location.longitude,
        description: description.trim() || undefined,
        photo_url: photoUrl,
      };

      if (isOnline) {
        // Submit directly if online
        const incident = await incidentService.create(incidentData);
        Alert.alert('Success', 'Incident reported successfully');
        onReportSuccess(incident);
      } else {
        // Queue for later if offline
        const queuedReport = await incidentService.queueOfflineReport(incidentData);
        Alert.alert(
          'Queued for Sync',
          'You are offline. Your report will be submitted when connection is restored.'
        );
        onReportSuccess(queuedReport);
      }

      handleClose();
    } catch (error) {
      console.error('Error submitting report:', error);
      
      // Handle rate limiting
      if (error.response?.status === 429) {
        const retryAfter = error.response?.data?.retry_after || 3600;
        Alert.alert(
          'Rate Limit Exceeded',
          `You can only create 5 incidents per hour. Please try again in ${Math.ceil(retryAfter / 60)} minutes.`
        );
      } else if (error.response?.status === 403) {
        Alert.alert('Account Flagged', error.response?.data?.message || 'Your account has been flagged. Please contact support.');
      } else {
        Alert.alert('Error', error.response?.data?.error || 'Failed to submit report');
      }
    } finally {
      setLoading(false);
      setUploadProgress(0);
    }
  };

  const handleClose = () => {
    setStep(1);
    setSelectedType(null);
    setDescription('');
    setPhoto(null);
    setLocation(null);
    onClose();
  };

  return (
    <Modal
      visible={visible}
      animationType="slide"
      transparent={true}
      onRequestClose={handleClose}
    >
      <View style={styles.modalOverlay}>
        <View style={styles.modalContent}>
          {/* Header */}
          <View style={styles.header}>
            <Text style={styles.headerTitle}>
              {step === 1 ? 'Report Incident' : `Report ${selectedType?.label}`}
            </Text>
            <TouchableOpacity onPress={handleClose} disabled={loading}>
              <Text style={styles.closeButton}>✕</Text>
            </TouchableOpacity>
          </View>

          {!isOnline && (
            <View style={styles.offlineBanner}>
              <Text style={styles.offlineText}>
                📡 Offline - Report will be queued for sync
              </Text>
            </View>
          )}

          <ScrollView style={styles.content}>
            {step === 1 ? (
              // Step 1: Type Selection
              <View style={styles.typeSelection}>
                <Text style={styles.sectionTitle}>Select Incident Type</Text>
                {INCIDENT_TYPES.map((type) => (
                  <TouchableOpacity
                    key={type.id}
                    style={[styles.typeButton, { borderColor: type.color }]}
                    onPress={() => handleTypeSelect(type)}
                  >
                    <Text style={styles.typeIcon}>{type.icon}</Text>
                    <Text style={[styles.typeLabel, { color: type.color }]}>
                      {type.label}
                    </Text>
                  </TouchableOpacity>
                ))}
              </View>
            ) : (
              // Step 2: Details
              <View style={styles.detailsForm}>
                {/* Location Info */}
                <View style={styles.locationInfo}>
                  <Text style={styles.locationLabel}>📍 Location captured</Text>
                  {location && (
                    <Text style={styles.locationCoords}>
                      {location.latitude.toFixed(6)}, {location.longitude.toFixed(6)}
                    </Text>
                  )}
                </View>

                {/* Description Input */}
                <View style={styles.inputGroup}>
                  <Text style={styles.inputLabel}>
                    Description (Optional, 10-500 characters)
                  </Text>
                  <TextInput
                    style={[
                      styles.textInput,
                      validationError && styles.textInputError,
                    ]}
                    placeholder="Describe what happened..."
                    value={description}
                    onChangeText={validateDescription}
                    maxLength={500}
                    multiline
                    numberOfLines={4}
                    textAlignVertical="top"
                  />
                  <View style={styles.inputFooter}>
                    <Text style={styles.charCount}>
                      {description.length}/500
                    </Text>
                  </View>
                  {validationError && (
                    <Text style={styles.errorText}>{validationError}</Text>
                  )}
                  {profanityWarning && (
                    <View style={styles.warningBanner}>
                      <Text style={styles.warningText}>
                        ⚠️ Your description may contain inappropriate language
                      </Text>
                    </View>
                  )}
                </View>

                {/* Photo Section */}
                <View style={styles.photoSection}>
                  <Text style={styles.inputLabel}>Photo (Optional, max 10MB)</Text>
                  {uploadProgress > 0 && uploadProgress < 100 && (
                    <View style={styles.progressBar}>
                      <View style={[styles.progressFill, { width: `${uploadProgress}%` }]} />
                    </View>
                  )}
                  {photo ? (
                    <View style={styles.photoPreview}>
                      <Image source={{ uri: photo.uri }} style={styles.photoImage} />
                      <Text style={styles.photoSize}>
                        Size: {(photo.size / (1024 * 1024)).toFixed(2)} MB
                      </Text>
                      <TouchableOpacity
                        style={styles.removePhotoButton}
                        onPress={() => setPhoto(null)}
                        disabled={loading}
                      >
                        <Text style={styles.removePhotoText}>✕ Remove</Text>
                      </TouchableOpacity>
                    </View>
                  ) : (
                    <View style={styles.photoButtons}>
                      <TouchableOpacity
                        style={styles.photoButton}
                        onPress={handleTakePhoto}
                        disabled={loading}
                      >
                        <Text style={styles.photoButtonText}>📷 Take Photo</Text>
                      </TouchableOpacity>
                      <TouchableOpacity
                        style={styles.photoButton}
                        onPress={handlePickPhoto}
                        disabled={loading}
                      >
                        <Text style={styles.photoButtonText}>🖼️ Choose Photo</Text>
                      </TouchableOpacity>
                    </View>
                  )}
                </View>

                {/* Action Buttons */}
                <View style={styles.actionButtons}>
                  <TouchableOpacity
                    style={styles.backButton}
                    onPress={() => setStep(1)}
                    disabled={loading}
                  >
                    <Text style={styles.backButtonText}>Back</Text>
                  </TouchableOpacity>
                  <TouchableOpacity
                    style={[
                      styles.submitButton,
                      { backgroundColor: selectedType?.color },
                      loading && styles.submitButtonDisabled,
                    ]}
                    onPress={handleSubmit}
                    disabled={loading}
                  >
                    {loading ? (
                      <ActivityIndicator color="#fff" />
                    ) : (
                      <Text style={styles.submitButtonText}>Submit Report</Text>
                    )}
                  </TouchableOpacity>
                </View>
              </View>
            )}
          </ScrollView>
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
    maxHeight: '90%',
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 20,
    borderBottomWidth: 1,
    borderBottomColor: '#E5E7EB',
  },
  headerTitle: {
    fontSize: 20,
    fontWeight: '700',
    color: '#111827',
  },
  closeButton: {
    fontSize: 24,
    color: '#9CA3AF',
  },
  offlineBanner: {
    backgroundColor: '#FEF3C7',
    padding: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#FCD34D',
  },
  offlineText: {
    color: '#92400E',
    fontSize: 14,
    textAlign: 'center',
    fontWeight: '600',
  },
  content: {
    padding: 20,
  },
  typeSelection: {
    gap: 12,
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#374151',
    marginBottom: 8,
  },
  typeButton: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 16,
    borderWidth: 2,
    borderRadius: 12,
    gap: 12,
  },
  typeIcon: {
    fontSize: 32,
  },
  typeLabel: {
    fontSize: 18,
    fontWeight: '600',
  },
  detailsForm: {
    gap: 20,
  },
  locationInfo: {
    backgroundColor: '#F3F4F6',
    padding: 12,
    borderRadius: 8,
  },
  locationLabel: {
    fontSize: 14,
    fontWeight: '600',
    color: '#374151',
    marginBottom: 4,
  },
  locationCoords: {
    fontSize: 12,
    color: '#6B7280',
  },
  inputGroup: {
    gap: 8,
  },
  inputLabel: {
    fontSize: 14,
    fontWeight: '600',
    color: '#374151',
  },
  textInput: {
    borderWidth: 1,
    borderColor: '#D1D5DB',
    borderRadius: 8,
    padding: 12,
    fontSize: 16,
    minHeight: 100,
  },
  charCount: {
    fontSize: 12,
    color: '#9CA3AF',
    textAlign: 'right',
  },
  inputFooter: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
  },
  textInputError: {
    borderColor: '#EF4444',
  },
  errorText: {
    fontSize: 12,
    color: '#EF4444',
    marginTop: 4,
  },
  warningBanner: {
    backgroundColor: '#FEF3C7',
    padding: 8,
    borderRadius: 6,
    marginTop: 8,
  },
  warningText: {
    fontSize: 12,
    color: '#92400E',
    fontWeight: '600',
  },
  photoSection: {
    gap: 8,
  },
  progressBar: {
    height: 4,
    backgroundColor: '#E5E7EB',
    borderRadius: 2,
    overflow: 'hidden',
    marginBottom: 8,
  },
  progressFill: {
    height: '100%',
    backgroundColor: '#3B82F6',
  },
  photoSize: {
    fontSize: 12,
    color: '#6B7280',
    marginTop: 4,
  },
  photoButtons: {
    flexDirection: 'row',
    gap: 12,
  },
  photoButton: {
    flex: 1,
    backgroundColor: '#F3F4F6',
    padding: 16,
    borderRadius: 8,
    alignItems: 'center',
  },
  photoButtonText: {
    fontSize: 14,
    fontWeight: '600',
    color: '#374151',
  },
  photoPreview: {
    gap: 12,
  },
  photoImage: {
    width: '100%',
    height: 200,
    borderRadius: 8,
  },
  removePhotoButton: {
    backgroundColor: '#FEE2E2',
    padding: 12,
    borderRadius: 8,
    alignItems: 'center',
  },
  removePhotoText: {
    color: '#DC2626',
    fontWeight: '600',
  },
  actionButtons: {
    flexDirection: 'row',
    gap: 12,
    marginTop: 8,
  },
  backButton: {
    flex: 1,
    backgroundColor: '#F3F4F6',
    padding: 16,
    borderRadius: 8,
    alignItems: 'center',
  },
  backButtonText: {
    fontSize: 16,
    fontWeight: '600',
    color: '#374151',
  },
  submitButton: {
    flex: 2,
    padding: 16,
    borderRadius: 8,
    alignItems: 'center',
  },
  submitButtonDisabled: {
    opacity: 0.6,
  },
  submitButtonText: {
    fontSize: 16,
    fontWeight: '700',
    color: '#fff',
  },
});

export default ReportIncidentModal;
