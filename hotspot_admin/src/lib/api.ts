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

// Zones API
export interface ZoneFilters {
  is_active?: string
  zone_type?: string
  risk_level?: string
  page?: number
  page_size?: number
}

export interface ZoneCreateInput {
  zone_type: 'hijacking' | 'mugging' | 'accident'
  latitude: number
  longitude: number
  radius_meters: number
  risk_level?: 'low' | 'medium' | 'high' | 'critical'
  incident_count?: number
  is_active?: boolean
}

export interface ZoneUpdateInput {
  latitude?: number
  longitude?: number
  radius_meters?: number
  risk_level?: 'low' | 'medium' | 'high' | 'critical'
  is_active?: boolean
  incident_count?: number
}

export const zonesApi = {
  list: async (filters: ZoneFilters = {}) => {
    const response = await apiClient.get('/api/admin/zones', {
      params: filters,
    })
    return response.data
  },
  
  get: async (id: string) => {
    const response = await apiClient.get(`/api/admin/zones/${id}`)
    return response.data
  },
  
  create: async (data: ZoneCreateInput) => {
    const response = await apiClient.post('/api/admin/zones', data)
    return response.data
  },
  
  update: async (id: string, data: ZoneUpdateInput) => {
    const response = await apiClient.put(`/api/admin/zones/${id}`, data)
    return response.data
  },
  
  delete: async (id: string) => {
    const response = await apiClient.delete(`/api/admin/zones/${id}`)
    return response.data
  },
  
  getIncidents: async (id: string, page = 1, pageSize = 20) => {
    const response = await apiClient.get(`/api/admin/zones/${id}/incidents`, {
      params: { page, page_size: pageSize },
    })
    return response.data
  },
  
  getStats: async (id: string) => {
    const response = await apiClient.get(`/api/admin/zones/${id}/stats`)
    return response.data
  },
}

// Analytics API
export interface AnalyticsDateRange {
  start_date?: string
  end_date?: string
}

export const analyticsApi = {
  getTrends: async (params: AnalyticsDateRange = {}) => {
    const response = await apiClient.get('/api/admin/analytics/trends', {
      params,
    })
    return response.data
  },
  
  getHeatmap: async (params: AnalyticsDateRange = {}) => {
    const response = await apiClient.get('/api/admin/analytics/heatmap', {
      params,
    })
    return response.data
  },
  
  getPeakHours: async (params: AnalyticsDateRange = {}) => {
    const response = await apiClient.get('/api/admin/analytics/peak-hours', {
      params,
    })
    return response.data
  },
  
  getUserMetrics: async (params: AnalyticsDateRange = {}) => {
    const response = await apiClient.get('/api/admin/analytics/users', {
      params,
    })
    return response.data
  },
  
  getRevenue: async (params: AnalyticsDateRange = {}) => {
    const response = await apiClient.get('/api/admin/analytics/revenue', {
      params,
    })
    return response.data
  },
  
  export: async (dataType: 'trends' | 'peak_hours' | 'heatmap', format: 'csv' | 'pdf', params: AnalyticsDateRange = {}) => {
    const response = await apiClient.post('/api/admin/analytics/export', {
      data_type: dataType,
      format,
      ...params,
    }, {
      responseType: format === 'csv' ? 'blob' : 'json',
    })
    return response.data
  },
}

// Partners API
export interface PartnerFilters {
  is_active?: string
  partner_type?: string
  search?: string
  page?: number
  page_size?: number
}

export interface PartnerInput {
  name: string
  logo_url?: string
  partner_type: 'insurance' | 'security' | 'roadside_assistance' | 'other'
  service_regions?: Record<string, unknown>
  is_active?: boolean
  monthly_fee?: number
  contract_start?: string
  contract_end?: string
  contact_email?: string
  contact_phone?: string
}

export interface Partner {
  id: string
  name: string
  logo_url?: string
  partner_type: string
  service_regions?: Record<string, unknown>
  is_active: boolean
  monthly_fee?: number
  contract_start?: string
  contract_end?: string
  contact_email?: string
  contact_phone?: string
  inserted_at: string
  updated_at: string
}

export interface PartnerStats {
  total_impressions: number
  total_clicks: number
  total_alerts: number
  click_through_rate: number
  revenue: number
  monthly_fee: number
}

export const partnersApi = {
  list: async (filters: PartnerFilters = {}) => {
    const response = await apiClient.get('/api/admin/partners', {
      params: filters,
    })
    return response.data
  },
  
  get: async (id: string) => {
    const response = await apiClient.get(`/api/admin/partners/${id}`)
    return response.data
  },
  
  create: async (data: PartnerInput) => {
    const response = await apiClient.post('/api/admin/partners', data)
    return response.data
  },
  
  update: async (id: string, data: Partial<PartnerInput>) => {
    const response = await apiClient.put(`/api/admin/partners/${id}`, data)
    return response.data
  },
  
  delete: async (id: string) => {
    const response = await apiClient.delete(`/api/admin/partners/${id}`)
    return response.data
  },
  
  getStats: async (id: string, startDate?: string, endDate?: string) => {
    const response = await apiClient.get(`/api/admin/partners/${id}/stats`, {
      params: {
        start_date: startDate,
        end_date: endDate,
      },
    })
    return response.data
  },
}
