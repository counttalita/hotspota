import { useState, useRef, useEffect } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { zonesApi, type ZoneFilters, type ZoneCreateInput, type ZoneUpdateInput } from '@/lib/api'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import {
  MapPin,
  Plus,
  Edit,
  Trash2,
  Eye,
  AlertTriangle,
  ChevronLeft,
  ChevronRight,
} from 'lucide-react'
import { toast } from 'sonner'

interface Zone {
  id: string
  zone_type: 'hijacking' | 'mugging' | 'accident'
  center_location: {
    latitude: number
    longitude: number
  }
  radius_meters: number
  incident_count: number
  risk_level: 'low' | 'medium' | 'high' | 'critical'
  is_active: boolean
  last_incident_at?: string
  created_at: string
  updated_at: string
}



export function ZonesPage() {
  const queryClient = useQueryClient()
  const mapContainer = useRef<HTMLDivElement>(null)
  const [filters, setFilters] = useState<ZoneFilters>({
    page: 1,
    page_size: 20,
    is_active: 'true',
  })
  const [selectedZone, setSelectedZone] = useState<Zone | null>(null)
  const [showCreateDialog, setShowCreateDialog] = useState(false)
  const [showEditDialog, setShowEditDialog] = useState(false)
  const [showDeleteDialog, setShowDeleteDialog] = useState(false)
  const [showStatsDialog, setShowStatsDialog] = useState(false)
  const [createMode, setCreateMode] = useState(false)
  const [newZoneData, setNewZoneData] = useState<Partial<ZoneCreateInput>>({
    zone_type: 'hijacking',
    radius_meters: 1000,
    risk_level: 'low',
    is_active: true,
  })
  const [editZoneData, setEditZoneData] = useState<Partial<ZoneUpdateInput>>({})

  const { data, isLoading } = useQuery({
    queryKey: ['zones', filters],
    queryFn: () => zonesApi.list(filters),
  })

  const { data: zoneStats } = useQuery({
    queryKey: ['zone-stats', selectedZone?.id],
    queryFn: () => zonesApi.getStats(selectedZone!.id),
    enabled: !!selectedZone && showStatsDialog,
  })

  const createMutation = useMutation({
    mutationFn: (data: ZoneCreateInput) => zonesApi.create(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['zones'] })
      toast.success('Zone created successfully')
      setShowCreateDialog(false)
      setCreateMode(false)
      setNewZoneData({
        zone_type: 'hijacking',
        radius_meters: 1000,
        risk_level: 'low',
        is_active: true,
      })
    },
    onError: (error: unknown) => {
      const errorMessage = error instanceof Error && 'response' in error 
        ? (error as { response?: { data?: { error?: string } } }).response?.data?.error 
        : 'Failed to create zone'
      toast.error(errorMessage || 'Failed to create zone')
    },
  })

  const updateMutation = useMutation({
    mutationFn: ({ id, data }: { id: string; data: ZoneUpdateInput }) =>
      zonesApi.update(id, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['zones'] })
      toast.success('Zone updated successfully')
      setShowEditDialog(false)
      setSelectedZone(null)
    },
    onError: (error: unknown) => {
      const errorMessage = error instanceof Error && 'response' in error 
        ? (error as { response?: { data?: { error?: string } } }).response?.data?.error 
        : 'Failed to update zone'
      toast.error(errorMessage || 'Failed to update zone')
    },
  })

  const deleteMutation = useMutation({
    mutationFn: (id: string) => zonesApi.delete(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['zones'] })
      toast.success('Zone deleted successfully')
      setShowDeleteDialog(false)
      setSelectedZone(null)
    },
    onError: () => {
      toast.error('Failed to delete zone')
    },
  })

  // Map functionality placeholder - will be implemented with MapLibre GL
  useEffect(() => {
    if (!mapContainer.current) return
    
    // Map initialization will be added after installing maplibre-gl
    // For now, show a placeholder
  }, [])

  // Handle map click for zone creation
  const handleMapClick = (lat: number, lng: number) => {
    if (createMode) {
      setNewZoneData((prev) => ({
        ...prev,
        latitude: lat,
        longitude: lng,
      }))
      setShowCreateDialog(true)
      setCreateMode(false)
    }
  }

  const handleFilterChange = (key: keyof ZoneFilters, value: string | number | undefined) => {
    setFilters((prev) => ({ ...prev, [key]: value, page: 1 }))
  }

  const handleCreateZone = () => {
    if (!newZoneData.latitude || !newZoneData.longitude || !newZoneData.zone_type || !newZoneData.radius_meters) {
      toast.error('Please fill in all required fields')
      return
    }

    createMutation.mutate(newZoneData as ZoneCreateInput)
  }

  const handleUpdateZone = () => {
    if (!selectedZone) return

    updateMutation.mutate({
      id: selectedZone.id,
      data: editZoneData,
    })
  }

  const handleDeleteZone = () => {
    if (!selectedZone) return

    deleteMutation.mutate(selectedZone.id)
  }

  const handleEditClick = (zone: Zone) => {
    setSelectedZone(zone)
    setEditZoneData({
      radius_meters: zone.radius_meters,
      risk_level: zone.risk_level,
      is_active: zone.is_active,
    })
    setShowEditDialog(true)
  }

  const getRiskLevelColor = (level: string) => {
    switch (level) {
      case 'critical':
        return 'bg-red-100 text-red-800'
      case 'high':
        return 'bg-orange-100 text-orange-800'
      case 'medium':
        return 'bg-yellow-100 text-yellow-800'
      case 'low':
        return 'bg-green-100 text-green-800'
      default:
        return 'bg-gray-100 text-gray-800'
    }
  }

  const getZoneTypeColor = (type: string) => {
    switch (type) {
      case 'hijacking':
        return 'bg-red-100 text-red-800'
      case 'mugging':
        return 'bg-orange-100 text-orange-800'
      case 'accident':
        return 'bg-blue-100 text-blue-800'
      default:
        return 'bg-gray-100 text-gray-800'
    }
  }



  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold">Hotspot Zone Management</h1>
          <p className="text-gray-600 mt-1">
            Manage geofenced hotspot zones and view statistics
          </p>
        </div>
        <Button
          onClick={() => {
            setCreateMode(true)
            toast.info('Click on the map to place a new zone')
          }}
          disabled={createMode}
        >
          <Plus className="h-4 w-4 mr-2" />
          Create Zone
        </Button>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Map View */}
        <Card className="lg:col-span-1">
          <CardHeader>
            <CardTitle>Map View</CardTitle>
          </CardHeader>
          <CardContent>
            <div
              ref={mapContainer}
              className="w-full h-[500px] rounded-lg border bg-gray-100 flex items-center justify-center"
              onClick={() => {
                // Placeholder for map click - will be replaced with actual map
                if (createMode) {
                  handleMapClick(-26.2041, 28.0473)
                }
              }}
            >
              <div className="text-center text-gray-500">
                <MapPin className="h-12 w-12 mx-auto mb-2" />
                <p>Map view will be displayed here</p>
                <p className="text-sm mt-1">Install maplibre-gl to enable interactive map</p>
              </div>
            </div>
            {createMode && (
              <div className="mt-4 p-4 bg-blue-50 border border-blue-200 rounded-lg">
                <p className="text-sm text-blue-800">
                  <MapPin className="inline h-4 w-4 mr-1" />
                  Click on the map to place a new hotspot zone
                </p>
              </div>
            )}
          </CardContent>
        </Card>

        {/* Zone List */}
        <Card className="lg:col-span-1">
          <CardHeader>
            <div className="flex flex-col gap-4">
              <CardTitle>Zones List</CardTitle>
              <div className="flex gap-2">
                <Select
                  value={filters.is_active || 'all'}
                  onValueChange={(value) =>
                    handleFilterChange('is_active', value === 'all' ? undefined : value)
                  }
                >
                  <SelectTrigger className="w-[140px]">
                    <SelectValue placeholder="Status" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="all">All Zones</SelectItem>
                    <SelectItem value="true">Active</SelectItem>
                    <SelectItem value="false">Inactive</SelectItem>
                  </SelectContent>
                </Select>
                <Select
                  value={filters.zone_type || 'all'}
                  onValueChange={(value) =>
                    handleFilterChange('zone_type', value === 'all' ? undefined : value)
                  }
                >
                  <SelectTrigger className="w-[140px]">
                    <SelectValue placeholder="Type" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="all">All Types</SelectItem>
                    <SelectItem value="hijacking">Hijacking</SelectItem>
                    <SelectItem value="mugging">Mugging</SelectItem>
                    <SelectItem value="accident">Accident</SelectItem>
                  </SelectContent>
                </Select>
                <Select
                  value={filters.risk_level || 'all'}
                  onValueChange={(value) =>
                    handleFilterChange('risk_level', value === 'all' ? undefined : value)
                  }
                >
                  <SelectTrigger className="w-[140px]">
                    <SelectValue placeholder="Risk Level" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="all">All Levels</SelectItem>
                    <SelectItem value="low">Low</SelectItem>
                    <SelectItem value="medium">Medium</SelectItem>
                    <SelectItem value="high">High</SelectItem>
                    <SelectItem value="critical">Critical</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </div>
          </CardHeader>
          <CardContent>
            <div className="space-y-3 max-h-[400px] overflow-y-auto">
              {isLoading ? (
                [...Array(5)].map((_, i) => (
                  <div key={i} className="h-20 bg-gray-100 animate-pulse rounded" />
                ))
              ) : data?.data && data.data.length > 0 ? (
                data.data.map((zone: Zone) => (
                  <div
                    key={zone.id}
                    className={`p-4 border rounded-lg cursor-pointer transition-colors ${
                      selectedZone?.id === zone.id
                        ? 'border-blue-500 bg-blue-50'
                        : 'hover:bg-gray-50'
                    }`}
                    onClick={() => setSelectedZone(zone)}
                  >
                    <div className="flex items-start justify-between">
                      <div className="flex-1">
                        <div className="flex items-center gap-2 mb-2">
                          <span className={`px-2 py-1 rounded-full text-xs font-medium ${getZoneTypeColor(zone.zone_type)}`}>
                            {zone.zone_type}
                          </span>
                          <span className={`px-2 py-1 rounded-full text-xs font-medium ${getRiskLevelColor(zone.risk_level)}`}>
                            {zone.risk_level}
                          </span>
                          {!zone.is_active && (
                            <span className="px-2 py-1 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                              Inactive
                            </span>
                          )}
                        </div>
                        <div className="text-sm text-gray-600">
                          <div>
                            <MapPin className="inline h-3 w-3 mr-1" />
                            {zone.center_location.latitude.toFixed(4)}, {zone.center_location.longitude.toFixed(4)}
                          </div>
                          <div className="mt-1">
                            <AlertTriangle className="inline h-3 w-3 mr-1" />
                            {zone.incident_count} incidents • {(zone.radius_meters / 1000).toFixed(1)} km radius
                          </div>
                        </div>
                      </div>
                      <div className="flex gap-1">
                        <Button
                          size="sm"
                          variant="ghost"
                          onClick={(e) => {
                            e.stopPropagation()
                            setSelectedZone(zone)
                            setShowStatsDialog(true)
                          }}
                          title="View Stats"
                        >
                          <Eye className="h-4 w-4" />
                        </Button>
                        <Button
                          size="sm"
                          variant="ghost"
                          onClick={(e) => {
                            e.stopPropagation()
                            handleEditClick(zone)
                          }}
                          title="Edit Zone"
                        >
                          <Edit className="h-4 w-4" />
                        </Button>
                        <Button
                          size="sm"
                          variant="ghost"
                          onClick={(e) => {
                            e.stopPropagation()
                            setSelectedZone(zone)
                            setShowDeleteDialog(true)
                          }}
                          title="Delete Zone"
                        >
                          <Trash2 className="h-4 w-4 text-red-600" />
                        </Button>
                      </div>
                    </div>
                  </div>
                ))
              ) : (
                <div className="text-center py-8 text-gray-500">
                  No zones found
                </div>
              )}
            </div>

            {data?.pagination && (
              <div className="flex items-center justify-between mt-4 pt-4 border-t">
                <div className="text-sm text-gray-600">
                  Page {data.pagination.page} of {data.pagination.total_pages}
                </div>
                <div className="flex items-center gap-2">
                  <Button
                    size="sm"
                    variant="outline"
                    onClick={() => handleFilterChange('page', filters.page! - 1)}
                    disabled={filters.page === 1}
                  >
                    <ChevronLeft className="h-4 w-4" />
                  </Button>
                  <Button
                    size="sm"
                    variant="outline"
                    onClick={() => handleFilterChange('page', filters.page! + 1)}
                    disabled={filters.page === data.pagination.total_pages}
                  >
                    <ChevronRight className="h-4 w-4" />
                  </Button>
                </div>
              </div>
            )}
          </CardContent>
        </Card>
      </div>

      {/* Create Zone Dialog */}
      <Dialog open={showCreateDialog} onOpenChange={setShowCreateDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Create New Hotspot Zone</DialogTitle>
            <DialogDescription>
              Configure the new hotspot zone properties
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4">
            <div>
              <label className="text-sm font-medium">Zone Type</label>
              <Select
                value={newZoneData.zone_type}
                onValueChange={(value: 'hijacking' | 'mugging' | 'accident') =>
                  setNewZoneData((prev) => ({ ...prev, zone_type: value }))
                }
              >
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="hijacking">Hijacking</SelectItem>
                  <SelectItem value="mugging">Mugging</SelectItem>
                  <SelectItem value="accident">Accident</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div>
              <label className="text-sm font-medium">Latitude</label>
              <Input
                type="number"
                step="0.0001"
                value={newZoneData.latitude || ''}
                onChange={(e) =>
                  setNewZoneData((prev) => ({ ...prev, latitude: parseFloat(e.target.value) }))
                }
              />
            </div>
            <div>
              <label className="text-sm font-medium">Longitude</label>
              <Input
                type="number"
                step="0.0001"
                value={newZoneData.longitude || ''}
                onChange={(e) =>
                  setNewZoneData((prev) => ({ ...prev, longitude: parseFloat(e.target.value) }))
                }
              />
            </div>
            <div>
              <label className="text-sm font-medium">Radius (meters)</label>
              <Input
                type="number"
                value={newZoneData.radius_meters || ''}
                onChange={(e) =>
                  setNewZoneData((prev) => ({ ...prev, radius_meters: parseInt(e.target.value) }))
                }
              />
            </div>
            <div>
              <label className="text-sm font-medium">Risk Level</label>
              <Select
                value={newZoneData.risk_level}
                onValueChange={(value: 'low' | 'medium' | 'high' | 'critical') =>
                  setNewZoneData((prev) => ({ ...prev, risk_level: value }))
                }
              >
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="low">Low</SelectItem>
                  <SelectItem value="medium">Medium</SelectItem>
                  <SelectItem value="high">High</SelectItem>
                  <SelectItem value="critical">Critical</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setShowCreateDialog(false)}>
              Cancel
            </Button>
            <Button onClick={handleCreateZone} disabled={createMutation.isPending}>
              {createMutation.isPending ? 'Creating...' : 'Create Zone'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Edit Zone Dialog */}
      <Dialog open={showEditDialog} onOpenChange={setShowEditDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Edit Hotspot Zone</DialogTitle>
            <DialogDescription>
              Update zone properties
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4">
            <div>
              <label className="text-sm font-medium">Radius (meters)</label>
              <Input
                type="number"
                value={editZoneData.radius_meters || ''}
                onChange={(e) =>
                  setEditZoneData((prev) => ({ ...prev, radius_meters: parseInt(e.target.value) }))
                }
              />
            </div>
            <div>
              <label className="text-sm font-medium">Risk Level</label>
              <Select
                value={editZoneData.risk_level}
                onValueChange={(value: 'low' | 'medium' | 'high' | 'critical') =>
                  setEditZoneData((prev) => ({ ...prev, risk_level: value }))
                }
              >
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="low">Low</SelectItem>
                  <SelectItem value="medium">Medium</SelectItem>
                  <SelectItem value="high">High</SelectItem>
                  <SelectItem value="critical">Critical</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="flex items-center gap-2">
              <input
                type="checkbox"
                id="is_active"
                checked={editZoneData.is_active ?? true}
                onChange={(e) =>
                  setEditZoneData((prev) => ({ ...prev, is_active: e.target.checked }))
                }
              />
              <label htmlFor="is_active" className="text-sm font-medium">
                Active
              </label>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setShowEditDialog(false)}>
              Cancel
            </Button>
            <Button onClick={handleUpdateZone} disabled={updateMutation.isPending}>
              {updateMutation.isPending ? 'Updating...' : 'Update Zone'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Delete Confirmation Dialog */}
      <Dialog open={showDeleteDialog} onOpenChange={setShowDeleteDialog}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Delete Hotspot Zone</DialogTitle>
            <DialogDescription>
              Are you sure you want to delete this zone? This action cannot be undone.
            </DialogDescription>
          </DialogHeader>
          <DialogFooter>
            <Button variant="outline" onClick={() => setShowDeleteDialog(false)}>
              Cancel
            </Button>
            <Button
              variant="destructive"
              onClick={handleDeleteZone}
              disabled={deleteMutation.isPending}
            >
              {deleteMutation.isPending ? 'Deleting...' : 'Delete Zone'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Zone Stats Dialog */}
      <Dialog open={showStatsDialog} onOpenChange={setShowStatsDialog}>
        <DialogContent className="max-w-2xl">
          <DialogHeader>
            <DialogTitle>Zone Statistics</DialogTitle>
            <DialogDescription>
              Entry/exit statistics for this hotspot zone
            </DialogDescription>
          </DialogHeader>
          {zoneStats?.data && (
            <div className="grid grid-cols-2 gap-4">
              <Card>
                <CardContent className="pt-6">
                  <div className="text-2xl font-bold">{zoneStats.data.total_entries}</div>
                  <div className="text-sm text-gray-600">Total Entries</div>
                </CardContent>
              </Card>
              <Card>
                <CardContent className="pt-6">
                  <div className="text-2xl font-bold">{zoneStats.data.current_users}</div>
                  <div className="text-sm text-gray-600">Current Users</div>
                </CardContent>
              </Card>
              <Card>
                <CardContent className="pt-6">
                  <div className="text-2xl font-bold">{zoneStats.data.completed_visits}</div>
                  <div className="text-sm text-gray-600">Completed Visits</div>
                </CardContent>
              </Card>
              <Card>
                <CardContent className="pt-6">
                  <div className="text-2xl font-bold">{zoneStats.data.avg_duration_minutes} min</div>
                  <div className="text-sm text-gray-600">Avg Duration</div>
                </CardContent>
              </Card>
              <Card>
                <CardContent className="pt-6">
                  <div className="text-2xl font-bold">{zoneStats.data.recent_entries_24h}</div>
                  <div className="text-sm text-gray-600">Entries (24h)</div>
                </CardContent>
              </Card>
              <Card>
                <CardContent className="pt-6">
                  <div className="text-2xl font-bold">{zoneStats.data.zone_age_days} days</div>
                  <div className="text-sm text-gray-600">Zone Age</div>
                </CardContent>
              </Card>
            </div>
          )}
          <DialogFooter>
            <Button onClick={() => setShowStatsDialog(false)}>Close</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
