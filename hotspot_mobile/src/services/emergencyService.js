import axios from 'axios';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { API_BASE_URL } from './config';

const api = axios.create({
  baseURL: API_BASE_URL,
  timeout: 10000,
});

// Add auth token to requests
api.interceptors.request.use(async (config) => {
  const token = await AsyncStorage.getItem('authToken');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

/**
 * Get all emergency contacts for the current user
 */
export const getEmergencyContacts = async () => {
  try {
    const response = await api.get('/emergency-contacts');
    return response.data.data;
  } catch (error) {
    console.error('Error fetching emergency contacts:', error);
    throw error;
  }
};

/**
 * Add a new emergency contact
 */
export const addEmergencyContact = async (contactData) => {
  try {
    const response = await api.post('/emergency-contacts', {
      emergency_contact: contactData,
    });
    return response.data.data;
  } catch (error) {
    console.error('Error adding emergency contact:', error);
    throw error;
  }
};

/**
 * Update an emergency contact
 */
export const updateEmergencyContact = async (contactId, contactData) => {
  try {
    const response = await api.put(`/emergency-contacts/${contactId}`, {
      emergency_contact: contactData,
    });
    return response.data.data;
  } catch (error) {
    console.error('Error updating emergency contact:', error);
    throw error;
  }
};

/**
 * Delete an emergency contact
 */
export const deleteEmergencyContact = async (contactId) => {
  try {
    await api.delete(`/emergency-contacts/${contactId}`);
    return true;
  } catch (error) {
    console.error('Error deleting emergency contact:', error);
    throw error;
  }
};

/**
 * Trigger panic button - sends alerts to emergency contacts
 */
export const triggerPanicButton = async (latitude, longitude) => {
  try {
    const response = await api.post('/emergency/panic', {
      latitude,
      longitude,
    });
    return response.data.data;
  } catch (error) {
    console.error('Error triggering panic button:', error);
    throw error;
  }
};

/**
 * Get current panic status
 */
export const getPanicStatus = async () => {
  try {
    const response = await api.get('/emergency/panic/status');
    return response.data;
  } catch (error) {
    console.error('Error getting panic status:', error);
    throw error;
  }
};

/**
 * Resolve/cancel active panic event
 */
export const resolvePanic = async (notes = null) => {
  try {
    const response = await api.post('/emergency/panic/resolve', {
      notes,
    });
    return response.data.data;
  } catch (error) {
    console.error('Error resolving panic:', error);
    throw error;
  }
};

/**
 * Find nearby emergency services (police stations and hospitals)
 */
export const findNearbyEmergencyServices = async (latitude, longitude, radius = 5000) => {
  try {
    const response = await api.get('/emergency-services/nearby', {
      params: {
        lat: latitude,
        lng: longitude,
        radius,
      },
    });
    return response.data.data;
  } catch (error) {
    console.error('Error finding nearby emergency services:', error);
    throw error;
  }
};

/**
 * Find nearby police stations only
 */
export const findNearbyPoliceStations = async (latitude, longitude, radius = 5000) => {
  try {
    const response = await api.get('/emergency-services/police', {
      params: {
        lat: latitude,
        lng: longitude,
        radius,
      },
    });
    return response.data.data;
  } catch (error) {
    console.error('Error finding nearby police stations:', error);
    throw error;
  }
};

/**
 * Find nearby hospitals only
 */
export const findNearbyHospitals = async (latitude, longitude, radius = 5000) => {
  try {
    const response = await api.get('/emergency-services/hospitals', {
      params: {
        lat: latitude,
        lng: longitude,
        radius,
      },
    });
    return response.data.data;
  } catch (error) {
    console.error('Error finding nearby hospitals:', error);
    throw error;
  }
};

export default {
  getEmergencyContacts,
  addEmergencyContact,
  updateEmergencyContact,
  deleteEmergencyContact,
  triggerPanicButton,
  getPanicStatus,
  resolvePanic,
  findNearbyEmergencyServices,
  findNearbyPoliceStations,
  findNearbyHospitals,
};
