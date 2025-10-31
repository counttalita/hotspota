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
 * Get all public groups or groups near a location
 */
export const getGroups = async (latitude = null, longitude = null, radius = 10000) => {
  try {
    const params = {};
    if (latitude && longitude) {
      params.latitude = latitude;
      params.longitude = longitude;
      params.radius = radius;
    }

    const response = await api.get('/communities', { params });
    return response.data.data;
  } catch (error) {
    console.error('Error fetching groups:', error);
    throw error;
  }
};

/**
 * Get groups that the current user is a member of
 */
export const getMyGroups = async () => {
  try {
    const response = await api.get('/communities/my-groups');
    return response.data.data;
  } catch (error) {
    console.error('Error fetching my groups:', error);
    throw error;
  }
};

/**
 * Get a single group by ID
 */
export const getGroup = async (groupId) => {
  try {
    const response = await api.get(`/communities/${groupId}`);
    return response.data.data;
  } catch (error) {
    console.error('Error fetching group:', error);
    throw error;
  }
};

/**
 * Create a new community group
 */
export const createGroup = async (groupData) => {
  try {
    const response = await api.post('/communities', { group: groupData });
    return response.data.data;
  } catch (error) {
    console.error('Error creating group:', error);
    throw error;
  }
};

/**
 * Update a group (admin only)
 */
export const updateGroup = async (groupId, groupData) => {
  try {
    const response = await api.put(`/communities/${groupId}`, { group: groupData });
    return response.data.data;
  } catch (error) {
    console.error('Error updating group:', error);
    throw error;
  }
};

/**
 * Delete a group (admin only)
 */
export const deleteGroup = async (groupId) => {
  try {
    await api.delete(`/communities/${groupId}`);
  } catch (error) {
    console.error('Error deleting group:', error);
    throw error;
  }
};

/**
 * Join a group
 */
export const joinGroup = async (groupId) => {
  try {
    const response = await api.post(`/communities/${groupId}/join`);
    return response.data.data;
  } catch (error) {
    console.error('Error joining group:', error);
    throw error;
  }
};

/**
 * Leave a group
 */
export const leaveGroup = async (groupId) => {
  try {
    await api.delete(`/communities/${groupId}/leave`);
  } catch (error) {
    console.error('Error leaving group:', error);
    throw error;
  }
};

/**
 * Get group members
 */
export const getGroupMembers = async (groupId) => {
  try {
    const response = await api.get(`/communities/${groupId}/members`);
    return response.data.data;
  } catch (error) {
    console.error('Error fetching group members:', error);
    throw error;
  }
};

/**
 * Update member role (admin only)
 */
export const updateMemberRole = async (groupId, userId, role) => {
  try {
    const response = await api.put(`/communities/${groupId}/members/${userId}/role`, { role });
    return response.data.data;
  } catch (error) {
    console.error('Error updating member role:', error);
    throw error;
  }
};

/**
 * Update notification preferences for a group
 */
export const updateNotificationPreferences = async (groupId, enabled) => {
  try {
    const response = await api.put(`/communities/${groupId}/notifications`, { enabled });
    return response.data.data;
  } catch (error) {
    console.error('Error updating notification preferences:', error);
    throw error;
  }
};

/**
 * Get incidents for a group
 */
export const getGroupIncidents = async (groupId, page = 1, pageSize = 20, type = null) => {
  try {
    const params = { page, page_size: pageSize };
    if (type) {
      params.type = type;
    }

    const response = await api.get(`/communities/${groupId}/incidents`, { params });
    return response.data;
  } catch (error) {
    console.error('Error fetching group incidents:', error);
    throw error;
  }
};

export default {
  getGroups,
  getMyGroups,
  getGroup,
  createGroup,
  updateGroup,
  deleteGroup,
  joinGroup,
  leaveGroup,
  getGroupMembers,
  updateMemberRole,
  updateNotificationPreferences,
  getGroupIncidents,
};
