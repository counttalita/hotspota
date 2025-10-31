import * as Haptics from 'expo-haptics';
import { Platform } from 'react-native';

/**
 * Haptic feedback utilities for enhanced user experience.
 * Provides tactile feedback for key interactions.
 */

/**
 * Light haptic feedback for subtle interactions
 * Use for: Button taps, toggle switches, selections
 */
export const lightHaptic = async () => {
  if (Platform.OS === 'ios' || Platform.OS === 'android') {
    try {
      await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    } catch (error) {
      console.warn('Haptic feedback not available:', error);
    }
  }
};

/**
 * Medium haptic feedback for standard interactions
 * Use for: Confirmations, successful actions, navigation
 */
export const mediumHaptic = async () => {
  if (Platform.OS === 'ios' || Platform.OS === 'android') {
    try {
      await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    } catch (error) {
      console.warn('Haptic feedback not available:', error);
    }
  }
};

/**
 * Heavy haptic feedback for important interactions
 * Use for: Errors, warnings, critical actions
 */
export const heavyHaptic = async () => {
  if (Platform.OS === 'ios' || Platform.OS === 'android') {
    try {
      await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Heavy);
    } catch (error) {
      console.warn('Haptic feedback not available:', error);
    }
  }
};

/**
 * Success haptic feedback
 * Use for: Successful submissions, completions
 */
export const successHaptic = async () => {
  if (Platform.OS === 'ios' || Platform.OS === 'android') {
    try {
      await Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    } catch (error) {
      console.warn('Haptic feedback not available:', error);
    }
  }
};

/**
 * Warning haptic feedback
 * Use for: Warnings, cautions, entering danger zones
 */
export const warningHaptic = async () => {
  if (Platform.OS === 'ios' || Platform.OS === 'android') {
    try {
      await Haptics.notificationAsync(Haptics.NotificationFeedbackType.Warning);
    } catch (error) {
      console.warn('Haptic feedback not available:', error);
    }
  }
};

/**
 * Error haptic feedback
 * Use for: Errors, failed actions, validation failures
 */
export const errorHaptic = async () => {
  if (Platform.OS === 'ios' || Platform.OS === 'android') {
    try {
      await Haptics.notificationAsync(Haptics.NotificationFeedbackType.Error);
    } catch (error) {
      console.warn('Haptic feedback not available:', error);
    }
  }
};

/**
 * Selection haptic feedback
 * Use for: Scrolling through lists, picker selections
 */
export const selectionHaptic = async () => {
  if (Platform.OS === 'ios' || Platform.OS === 'android') {
    try {
      await Haptics.selectionAsync();
    } catch (error) {
      console.warn('Haptic feedback not available:', error);
    }
  }
};

/**
 * Custom haptic pattern for SOS button
 * Provides urgent, attention-grabbing feedback
 */
export const sosHaptic = async () => {
  if (Platform.OS === 'ios' || Platform.OS === 'android') {
    try {
      // Triple heavy impact for urgency
      await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Heavy);
      await new Promise(resolve => setTimeout(resolve, 100));
      await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Heavy);
      await new Promise(resolve => setTimeout(resolve, 100));
      await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Heavy);
    } catch (error) {
      console.warn('Haptic feedback not available:', error);
    }
  }
};

/**
 * Custom haptic pattern for entering hotspot zone
 * Provides warning-style feedback
 */
export const hotspotZoneHaptic = async () => {
  if (Platform.OS === 'ios' || Platform.OS === 'android') {
    try {
      // Double warning pattern
      await Haptics.notificationAsync(Haptics.NotificationFeedbackType.Warning);
      await new Promise(resolve => setTimeout(resolve, 150));
      await Haptics.notificationAsync(Haptics.NotificationFeedbackType.Warning);
    } catch (error) {
      console.warn('Haptic feedback not available:', error);
    }
  }
};

/**
 * Haptic feedback for incident report submission
 */
export const reportSubmittedHaptic = async () => {
  if (Platform.OS === 'ios' || Platform.OS === 'android') {
    try {
      await Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      await new Promise(resolve => setTimeout(resolve, 100));
      await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    } catch (error) {
      console.warn('Haptic feedback not available:', error);
    }
  }
};

/**
 * Haptic feedback for verification/upvote
 */
export const verificationHaptic = async () => {
  if (Platform.OS === 'ios' || Platform.OS === 'android') {
    try {
      await Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    } catch (error) {
      console.warn('Haptic feedback not available:', error);
    }
  }
};

/**
 * Check if haptic feedback is available on the device
 */
export const isHapticAvailable = () => {
  return Platform.OS === 'ios' || Platform.OS === 'android';
};

/**
 * Haptic feedback presets for common actions
 */
export const HapticPresets = {
  // Button interactions
  buttonPress: lightHaptic,
  buttonLongPress: mediumHaptic,
  
  // Form interactions
  inputFocus: lightHaptic,
  inputError: errorHaptic,
  formSubmit: successHaptic,
  
  // Navigation
  tabSwitch: selectionHaptic,
  screenTransition: lightHaptic,
  
  // Map interactions
  markerTap: lightHaptic,
  mapZoom: selectionHaptic,
  
  // Incident actions
  reportIncident: reportSubmittedHaptic,
  verifyIncident: verificationHaptic,
  
  // Alerts
  enterHotspotZone: hotspotZoneHaptic,
  sosActivated: sosHaptic,
  dangerAlert: warningHaptic,
  
  // General feedback
  success: successHaptic,
  warning: warningHaptic,
  error: errorHaptic,
};

export default HapticPresets;
