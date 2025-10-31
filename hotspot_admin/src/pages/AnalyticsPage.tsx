import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Download, TrendingUp, Users, DollarSign, Clock } from 'lucide-react'
import { analyticsApi } from '@/lib/api'
import { format, subDays } from 'date-fns'
import {
  LineChart,
  Line,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
} from 'recharts'
import maplibregl from 'maplibre-gl'
import 'maplibre-gl/dist/maplibre-gl.css'
import { useEffect, useRef } from 'react'

interface DateRange {
  start_date: string
  end_date: string
}

export function AnalyticsPage() {
  const [dateRange, setDateRange] = useState<DateRange>({
    start_date: format(subDays(new Date(), 30), 'yyyy-MM-dd'),
    end_date: format(new Date(), 'yyyy-MM-dd'),
  })

  const [exportFormat, setExportFormat] = useState<'csv' | 'pdf'>('csv')
  const [exportType, setExportType] = useState<'trends' | 'peak_hours' | 'heatmap'>('trends')

  // Fetch analytics data
  const { data: trendsData, isLoading: trendsLoading } = useQuery({
    queryKey: ['analytics-trends', dateRange],
    queryFn: () => analyticsApi.getTrends(dateRange),
  })

  const { data: heatmapData, isLoading: heatmapLoading } = useQuery({
    queryKey: ['analytics-heatmap', dateRange],
    queryFn: () => analyticsApi.getHeatmap(dateRange),
  })

  const { data: peakHoursData, isLoading: peakHoursLoading } = useQuery({
    queryKey: ['analytics-peak-hours', dateRange],
    queryFn: () => analyticsApi.getPeakHours(dateRange),
  })

  const { data: userMetricsData, isLoading: userMetricsLoading } = useQuery({
    queryKey: ['analytics-users', dateRange],
    queryFn: () => analyticsApi.getUserMetrics(dateRange),
  })

  const { data: revenueData, isLoading: revenueLoading } = useQuery({
    queryKey: ['analytics-revenue', dateRange],
    queryFn: () => analyticsApi.getRevenue(dateRange),
  })

  const handleExport = async () => {
    try {
      const blob = await analyticsApi.export(exportType, exportFormat, dateRange)
      
      if (exportFormat === 'csv') {
        const url = window.URL.createObjectURL(new Blob([blob]))
        const link = document.createElement('a')
        link.href = url
        link.setAttribute('download', `analytics_${exportType}_${format(new Date(), 'yyyy-MM-dd')}.csv`)
        document.body.appendChild(link)
        link.click()
        link.remove()
      }
    } catch (error) {
      console.error('Export failed:', error)
    }
  }

  const handleDateRangeChange = (field: 'start_date' | 'end_date', value: string) => {
    setDateRange(prev => ({
      ...prev,
      [field]: value,
    }))
  }

  // Format trends data for chart
  const trendsChartData = trendsData?.data?.map((item: {
    date: string
    hijacking_count: number
    mugging_count: number
    accident_count: number
    total_count: number
  }) => ({
    date: format(new Date(item.date), 'MMM dd'),
    Hijacking: item.hijacking_count,
    Mugging: item.mugging_count,
    Accident: item.accident_count,
  })) || []

  // Format peak hours data for chart
  const peakHoursChartData = peakHoursData?.data?.map((item: {
    hour: number
    hijacking_count: number
    mugging_count: number
    accident_count: number
    total_count: number
  }) => ({
    hour: `${item.hour}:00`,
    Hijacking: item.hijacking_count,
    Mugging: item.mugging_count,
    Accident: item.accident_count,
  })) || []

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold">Analytics & Reporting</h1>
          <p className="text-gray-600 mt-1">
            Comprehensive platform insights and data visualization
          </p>
        </div>
        <div className="flex items-center space-x-2">
          <Select value={exportType} onValueChange={(value: 'trends' | 'peak_hours' | 'heatmap') => setExportType(value)}>
            <SelectTrigger className="w-[180px]">
              <SelectValue placeholder="Select data type" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="trends">Trends</SelectItem>
              <SelectItem value="peak_hours">Peak Hours</SelectItem>
              <SelectItem value="heatmap">Heatmap</SelectItem>
            </SelectContent>
          </Select>
          <Select value={exportFormat} onValueChange={(value: 'csv' | 'pdf') => setExportFormat(value)}>
            <SelectTrigger className="w-[120px]">
              <SelectValue placeholder="Format" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="csv">CSV</SelectItem>
              <SelectItem value="pdf">PDF</SelectItem>
            </SelectContent>
          </Select>
          <Button onClick={handleExport}>
            <Download className="h-4 w-4 mr-2" />
            Export
          </Button>
        </div>
      </div>

      {/* Date Range Filter */}
      <Card>
        <CardHeader>
          <CardTitle>Date Range</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label htmlFor="start_date">Start Date</Label>
              <Input
                id="start_date"
                type="date"
                value={dateRange.start_date}
                onChange={(e) => handleDateRangeChange('start_date', e.target.value)}
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="end_date">End Date</Label>
              <Input
                id="end_date"
                type="date"
                value={dateRange.end_date}
                onChange={(e) => handleDateRangeChange('end_date', e.target.value)}
              />
            </div>
          </div>
        </CardContent>
      </Card>

      {/* User Engagement Metrics */}
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">
              Daily Active Users
            </CardTitle>
            <Users className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            {userMetricsLoading ? (
              <div className="h-8 w-24 bg-gray-200 animate-pulse rounded" />
            ) : (
              <>
                <div className="text-2xl font-bold">
                  {userMetricsData?.data?.daily_active_users?.toLocaleString() || 0}
                </div>
                <p className="text-xs text-muted-foreground">
                  Active in selected period
                </p>
              </>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">
              Retention Rate
            </CardTitle>
            <TrendingUp className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            {userMetricsLoading ? (
              <div className="h-8 w-24 bg-gray-200 animate-pulse rounded" />
            ) : (
              <>
                <div className="text-2xl font-bold">
                  {userMetricsData?.data?.retention_rate || 0}%
                </div>
                <p className="text-xs text-muted-foreground">
                  User retention
                </p>
              </>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">
              Verification Rate
            </CardTitle>
            <Clock className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            {userMetricsLoading ? (
              <div className="h-8 w-24 bg-gray-200 animate-pulse rounded" />
            ) : (
              <>
                <div className="text-2xl font-bold">
                  {userMetricsData?.data?.verification_participation_rate || 0}%
                </div>
                <p className="text-xs text-muted-foreground">
                  Users verifying incidents
                </p>
              </>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">
              Avg Verifications
            </CardTitle>
            <TrendingUp className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            {userMetricsLoading ? (
              <div className="h-8 w-24 bg-gray-200 animate-pulse rounded" />
            ) : (
              <>
                <div className="text-2xl font-bold">
                  {userMetricsData?.data?.average_verifications_per_incident || 0}
                </div>
                <p className="text-xs text-muted-foreground">
                  Per incident
                </p>
              </>
            )}
          </CardContent>
        </Card>
      </div>

      {/* Revenue Metrics */}
      <div className="grid gap-4 md:grid-cols-3">
        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">
              Total Revenue
            </CardTitle>
            <DollarSign className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            {revenueLoading ? (
              <div className="h-8 w-24 bg-gray-200 animate-pulse rounded" />
            ) : (
              <>
                <div className="text-2xl font-bold">
                  R{((revenueData?.data?.total_revenue || 0) / 100).toLocaleString()}
                </div>
                <p className="text-xs text-muted-foreground">
                  {revenueData?.data?.monthly_subscriptions + revenueData?.data?.annual_subscriptions || 0} subscriptions
                </p>
              </>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">
              Monthly Plans
            </CardTitle>
            <DollarSign className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            {revenueLoading ? (
              <div className="h-8 w-24 bg-gray-200 animate-pulse rounded" />
            ) : (
              <>
                <div className="text-2xl font-bold">
                  {revenueData?.data?.monthly_subscriptions || 0}
                </div>
                <p className="text-xs text-muted-foreground">
                  R{((revenueData?.data?.monthly_revenue || 0) / 100).toLocaleString()} revenue
                </p>
              </>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium">
              Annual Plans
            </CardTitle>
            <DollarSign className="h-4 w-4 text-muted-foreground" />
          </CardHeader>
          <CardContent>
            {revenueLoading ? (
              <div className="h-8 w-24 bg-gray-200 animate-pulse rounded" />
            ) : (
              <>
                <div className="text-2xl font-bold">
                  {revenueData?.data?.annual_subscriptions || 0}
                </div>
                <p className="text-xs text-muted-foreground">
                  R{((revenueData?.data?.annual_revenue || 0) / 100).toLocaleString()} revenue
                </p>
              </>
            )}
          </CardContent>
        </Card>
      </div>

      {/* Charts */}
      <Tabs defaultValue="trends" className="space-y-4">
        <TabsList>
          <TabsTrigger value="trends">Incident Trends</TabsTrigger>
          <TabsTrigger value="peak-hours">Peak Hours</TabsTrigger>
          <TabsTrigger value="heatmap">Geographic Heatmap</TabsTrigger>
        </TabsList>

        <TabsContent value="trends" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle>Incident Trends Over Time</CardTitle>
            </CardHeader>
            <CardContent>
              {trendsLoading ? (
                <div className="h-[400px] flex items-center justify-center">
                  <div className="text-muted-foreground">Loading chart...</div>
                </div>
              ) : trendsChartData.length > 0 ? (
                <ResponsiveContainer width="100%" height={400}>
                  <LineChart data={trendsChartData}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="date" />
                    <YAxis />
                    <Tooltip />
                    <Legend />
                    <Line type="monotone" dataKey="Hijacking" stroke="#dc2626" strokeWidth={2} />
                    <Line type="monotone" dataKey="Mugging" stroke="#ea580c" strokeWidth={2} />
                    <Line type="monotone" dataKey="Accident" stroke="#2563eb" strokeWidth={2} />
                  </LineChart>
                </ResponsiveContainer>
              ) : (
                <div className="h-[400px] flex items-center justify-center">
                  <div className="text-muted-foreground">No data available for selected period</div>
                </div>
              )}
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="peak-hours" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle>Peak Hours Analysis</CardTitle>
            </CardHeader>
            <CardContent>
              {peakHoursLoading ? (
                <div className="h-[400px] flex items-center justify-center">
                  <div className="text-muted-foreground">Loading chart...</div>
                </div>
              ) : peakHoursChartData.length > 0 ? (
                <ResponsiveContainer width="100%" height={400}>
                  <BarChart data={peakHoursChartData}>
                    <CartesianGrid strokeDasharray="3 3" />
                    <XAxis dataKey="hour" />
                    <YAxis />
                    <Tooltip />
                    <Legend />
                    <Bar dataKey="Hijacking" fill="#dc2626" />
                    <Bar dataKey="Mugging" fill="#ea580c" />
                    <Bar dataKey="Accident" fill="#2563eb" />
                  </BarChart>
                </ResponsiveContainer>
              ) : (
                <div className="h-[400px] flex items-center justify-center">
                  <div className="text-muted-foreground">No data available for selected period</div>
                </div>
              )}
            </CardContent>
          </Card>
        </TabsContent>

        <TabsContent value="heatmap" className="space-y-4">
          <Card>
            <CardHeader>
              <CardTitle>Geographic Heatmap</CardTitle>
            </CardHeader>
            <CardContent>
              <HeatmapView data={heatmapData?.data || []} isLoading={heatmapLoading} />
            </CardContent>
          </Card>
        </TabsContent>
      </Tabs>
    </div>
  )
}

// Heatmap component using MapLibre
interface HeatmapViewProps {
  data: Array<{
    latitude: number
    longitude: number
    incident_count: number
    dominant_type: string
  }>
  isLoading: boolean
}

function HeatmapView({ data, isLoading }: HeatmapViewProps) {
  const mapContainer = useRef<HTMLDivElement>(null)
  const map = useRef<maplibregl.Map | null>(null)

  useEffect(() => {
    if (!mapContainer.current || map.current) return

    // Initialize map
    map.current = new maplibregl.Map({
      container: mapContainer.current,
      style: 'https://demotiles.maplibre.org/style.json',
      center: [28.0473, -26.2041], // Johannesburg
      zoom: 10,
    })

    return () => {
      map.current?.remove()
      map.current = null
    }
  }, [])

  useEffect(() => {
    if (!map.current || !data || data.length === 0) return

    // Clear existing markers
    const markers = document.querySelectorAll('.maplibregl-marker')
    markers.forEach(marker => marker.remove())

    // Add markers for each cluster
    data.forEach((point) => {
      const el = document.createElement('div')
      el.className = 'heatmap-marker'
      el.style.width = `${Math.min(point.incident_count * 3, 60)}px`
      el.style.height = `${Math.min(point.incident_count * 3, 60)}px`
      el.style.borderRadius = '50%'
      el.style.opacity = '0.6'
      
      // Color based on dominant type
      const color = point.dominant_type === 'hijacking' ? '#dc2626' :
                    point.dominant_type === 'mugging' ? '#ea580c' : '#2563eb'
      el.style.backgroundColor = color

      new maplibregl.Marker({ element: el })
        .setLngLat([point.longitude, point.latitude])
        .setPopup(
          new maplibregl.Popup({ offset: 25 })
            .setHTML(`
              <div class="p-2">
                <p class="font-semibold">${point.incident_count} incidents</p>
                <p class="text-sm text-gray-600">Type: ${point.dominant_type}</p>
              </div>
            `)
        )
        .addTo(map.current!)
    })

    // Fit bounds to show all markers
    if (data.length > 0) {
      const bounds = new maplibregl.LngLatBounds()
      data.forEach(point => {
        bounds.extend([point.longitude, point.latitude])
      })
      map.current.fitBounds(bounds, { padding: 50 })
    }
  }, [data])

  if (isLoading) {
    return (
      <div className="h-[400px] flex items-center justify-center bg-gray-100 rounded">
        <div className="text-muted-foreground">Loading map...</div>
      </div>
    )
  }

  if (!data || data.length === 0) {
    return (
      <div className="h-[400px] flex items-center justify-center bg-gray-100 rounded">
        <div className="text-muted-foreground">No heatmap data available for selected period</div>
      </div>
    )
  }

  return <div ref={mapContainer} className="h-[400px] rounded" />
}
