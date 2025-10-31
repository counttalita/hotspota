import axios from 'axios'
import { useAuthStore } from '@/stores/authStore'

const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:4000'

export const apiClient = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
})

// Request interceptor to add auth token
apiClient.interceptors.request.use(
  (config) => {
    const token = useAuthStore.getState().token
    if (token) {
      config.headers.Authorization = `Bearer ${token}`
    }
    return config
  },
  (error) => {
    return Promise.reject(error)
  }
)

// Response interceptor to handle auth errors
apiClient.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      useAuthStore.getState().logout()
      window.location.href = '/login'
    }
    return Promise.reject(error)
  }
)

// Auth API
export const authApi = {
  login: async (email: string, password: string) => {
    const response = await apiClient.post('/api/admin/auth/login', {
      email,
      password,
    })
    return response.data
  },
  
  getMe: async () => {
    const response = await apiClient.get('/api/admin/auth/me')
    return response.data
  },
  
  logout: async () => {
    const response = await apiClient.post('/api/admin/auth/logout')
    return response.data
  },
}

// Dashboard API
export const dashboardApi = {
  getStats: async () => {
    const response = await apiClient.get('/api/admin/dashboard/stats')
    return response.data
  },
  
  getActivity: async (limit = 20) => {
    const response = await apiClient.get('/api/admin/dashboard/activity', {
      params: { limit },
    })
    return response.data
  },
}

// Incidents API
export interface IncidentFilters {
  type?: string
  status?: string
  search?: string
  start_date?: string
  end_date?: string
  is_verified?: string
  page?: number
  page_size?: number
  sort_by?: string
  sort_order?: 'asc' | 'desc'
}

export const incidentsApi = {
  list: async (filters: IncidentFilters = {}) => {
    const response = await apiClient.get('/api/admin/incidents', {
      params: filters,
    })
    return response.data
  },
  
  get: async (id: string) => {
    const response = await apiClient.get(`/api/admin/incidents/${id}`)
    return response.data
  },
  
  moderate: async (id: string, action: 'approve' | 'flag' | 'delete', reason?: string) => {
    const response = await apiClient.put(`/api/admin/incidents/${id}/moderate`, {
      action,
      reason,
    })
    return response.data
  },
  
  bulkAction: async (incidentIds: string[], action: 'approve' | 'flag' | 'delete', reason?: string) => {
    const response = await apiClient.post('/api/admin/incidents/bulk-action', {
      incident_ids: incidentIds,
      action,
      reason,
    })
    return response.data
  },
  
  delete: async (id: string) => {
    const response = await apiClient.delete(`/api/admin/incidents/${id}`)
    return response.data
  },
}

// Users API
export interface UserFilters {
  is_premium?: string
  search?: string
  start_date?: string
  end_date?: string
  page?: number
  page_size?: number
  sort_by?: string
  sort_order?: 'asc' | 'desc'
}

export const usersApi = {
  list: async (filters: UserFilters = {}) => {
    const response = await apiClient.get('/api/admin/users', {
      params: filters,
    })
    return response.data
  },
  
  get: async (id: string) => {
    const response = await apiClient.get(`/api/admin/users/${id}`)
    return response.data
  },
  
  suspend: async (id: string, reason?: string) => {
    const response = await apiClient.put(`/api/admin/users/${id}/suspend`, {
      reason,
    })
    return response.data
  },
  
  ban: async (id: string, reason?: string) => {
    const response = await apiClient.put(`/api/admin/users/${id}/ban`, {
      reason,
    })
    return response.data
  },
  
  updatePremium: async (id: string, isPremium: boolean, expiresAt?: string) => {
    const response = await apiClient.put(`/api/admin/users/${id}/premium`, {
      is_premium: isPremium,
      expires_at: expiresAt,
    })
    return response.data
  },
  
  notify: async (id: string, title: string, message: string) => {
    const response = await apiClient.post(`/api/admin/users/${id}/notify`, {
      title,
      message,
    })
    return response.data
  },
  
  getActivity: async (id: string, limit = 50) => {
    const response = await apiClient.get(`/api/admin/users/${id}/activity`, {
      params: { limit },
    })
    return response.data
  },
}
