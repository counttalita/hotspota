import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { incidentsApi, type IncidentFilters } from '@/lib/api'
import { Card, CardContent, CardHeader } from '@/components/ui/card'
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
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'
import { Checkbox } from '@/components/ui/checkbox'
import {
  Search,
  CheckCircle,
  Flag,
  Trash2,
  Eye,
  ChevronLeft,
  ChevronRight,
} from 'lucide-react'
import { IncidentDetailModal } from '@/components/IncidentDetailModal'
import { toast } from 'sonner'

interface Incident {
  id: string
  type: string
  description?: string
  photo_url?: string
  location: {
    latitude: number
    longitude: number
  }
  verification_count: number
  is_verified: boolean
  status: string
  created_at: string
  expires_at: string
  user?: {
    id: string
    phone_number: string
    is_premium: boolean
  }
}

export function IncidentsPage() {
  const queryClient = useQueryClient()
  const [filters, setFilters] = useState<IncidentFilters>({
    page: 1,
    page_size: 20,
    sort_by: 'inserted_at',
    sort_order: 'desc',
  })
  const [selectedIds, setSelectedIds] = useState<string[]>([])
  const [selectedIncident, setSelectedIncident] = useState<string | null>(null)

  const { data, isLoading } = useQuery({
    queryKey: ['incidents', filters],
    queryFn: () => incidentsApi.list(filters),
  })

  const moderateMutation = useMutation({
    mutationFn: ({ id, action, reason }: { id: string; action: 'approve' | 'flag' | 'delete'; reason?: string }) =>
      incidentsApi.moderate(id, action, reason),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['incidents'] })
      toast.success('Incident moderated successfully')
    },
    onError: () => {
      toast.error('Failed to moderate incident')
    },
  })

  const bulkActionMutation = useMutation({
    mutationFn: ({ action, reason }: { action: 'approve' | 'flag' | 'delete'; reason?: string }) =>
      incidentsApi.bulkAction(selectedIds, action, reason),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['incidents'] })
      setSelectedIds([])
      toast.success('Bulk action completed successfully')
    },
    onError: () => {
      toast.error('Failed to perform bulk action')
    },
  })

  const handleFilterChange = (key: keyof IncidentFilters, value: string | number | undefined) => {
    setFilters((prev) => ({ ...prev, [key]: value, page: 1 }))
  }

  const handleSelectAll = (checked: boolean) => {
    if (checked) {
      setSelectedIds(data?.data?.map((incident: Incident) => incident.id) || [])
    } else {
      setSelectedIds([])
    }
  }

  const handleSelectOne = (id: string, checked: boolean) => {
    if (checked) {
      setSelectedIds((prev) => [...prev, id])
    } else {
      setSelectedIds((prev) => prev.filter((selectedId) => selectedId !== id))
    }
  }

  const getIncidentTypeColor = (type: string) => {
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

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleString('en-ZA', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    })
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold">Incident Management</h1>
          <p className="text-gray-600 mt-1">
            Review and moderate incident reports
          </p>
        </div>
      </div>

      <Card>
        <CardHeader>
          <div className="flex flex-col md:flex-row gap-4">
            <div className="flex-1 relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
              <Input
                placeholder="Search incidents..."
                className="pl-10"
                value={filters.search || ''}
                onChange={(e) => handleFilterChange('search', e.target.value)}
              />
            </div>
            <Select
              value={filters.type || 'all'}
              onValueChange={(value) => handleFilterChange('type', value === 'all' ? undefined : value)}
            >
              <SelectTrigger className="w-[180px]">
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
              value={filters.status || 'all'}
              onValueChange={(value) => handleFilterChange('status', value === 'all' ? undefined : value)}
            >
              <SelectTrigger className="w-[180px]">
                <SelectValue placeholder="Status" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All Status</SelectItem>
                <SelectItem value="active">Active</SelectItem>
                <SelectItem value="expired">Expired</SelectItem>
              </SelectContent>
            </Select>
            <Select
              value={filters.is_verified || 'all'}
              onValueChange={(value) => handleFilterChange('is_verified', value === 'all' ? undefined : value)}
            >
              <SelectTrigger className="w-[180px]">
                <SelectValue placeholder="Verification" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All</SelectItem>
                <SelectItem value="true">Verified</SelectItem>
                <SelectItem value="false">Unverified</SelectItem>
              </SelectContent>
            </Select>
          </div>
        </CardHeader>
        <CardContent>
          {selectedIds.length > 0 && (
            <div className="mb-4 flex items-center gap-2 p-3 bg-blue-50 rounded-lg">
              <span className="text-sm font-medium">
                {selectedIds.length} selected
              </span>
              <div className="flex gap-2 ml-auto">
                <Button
                  size="sm"
                  variant="outline"
                  onClick={() => bulkActionMutation.mutate({ action: 'approve' })}
                  disabled={bulkActionMutation.isPending}
                >
                  <CheckCircle className="h-4 w-4 mr-1" />
                  Approve
                </Button>
                <Button
                  size="sm"
                  variant="outline"
                  onClick={() => bulkActionMutation.mutate({ action: 'flag', reason: 'Bulk flagged by admin' })}
                  disabled={bulkActionMutation.isPending}
                >
                  <Flag className="h-4 w-4 mr-1" />
                  Flag
                </Button>
                <Button
                  size="sm"
                  variant="destructive"
                  onClick={() => {
                    if (confirm(`Delete ${selectedIds.length} incidents?`)) {
                      bulkActionMutation.mutate({ action: 'delete' })
                    }
                  }}
                  disabled={bulkActionMutation.isPending}
                >
                  <Trash2 className="h-4 w-4 mr-1" />
                  Delete
                </Button>
              </div>
            </div>
          )}

          <div className="rounded-md border">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead className="w-12">
                    <Checkbox
                      checked={selectedIds.length === data?.data?.length && data?.data?.length > 0}
                      onCheckedChange={handleSelectAll}
                    />
                  </TableHead>
                  <TableHead>Type</TableHead>
                  <TableHead>Description</TableHead>
                  <TableHead>User</TableHead>
                  <TableHead>Verifications</TableHead>
                  <TableHead>Created</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead className="text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {isLoading ? (
                  [...Array(5)].map((_, i) => (
                    <TableRow key={i}>
                      <TableCell colSpan={8}>
                        <div className="h-12 bg-gray-100 animate-pulse rounded" />
                      </TableCell>
                    </TableRow>
                  ))
                ) : data?.data && data.data.length > 0 ? (
                  data.data.map((incident: Incident) => (
                    <TableRow key={incident.id}>
                      <TableCell>
                        <Checkbox
                          checked={selectedIds.includes(incident.id)}
                          onCheckedChange={(checked) => handleSelectOne(incident.id, checked as boolean)}
                        />
                      </TableCell>
                      <TableCell>
                        <span className={`px-2 py-1 rounded-full text-xs font-medium ${getIncidentTypeColor(incident.type)}`}>
                          {incident.type}
                        </span>
                      </TableCell>
                      <TableCell className="max-w-xs truncate">
                        {incident.description || 'No description'}
                      </TableCell>
                      <TableCell className="text-sm text-gray-600">
                        {incident.user?.phone_number || 'Unknown'}
                      </TableCell>
                      <TableCell>
                        <div className="flex items-center gap-1">
                          <span className="text-sm font-medium">{incident.verification_count}</span>
                          {incident.is_verified && (
                            <CheckCircle className="h-4 w-4 text-green-600" />
                          )}
                        </div>
                      </TableCell>
                      <TableCell className="text-sm text-gray-600">
                        {formatDate(incident.created_at)}
                      </TableCell>
                      <TableCell>
                        <span className={`px-2 py-1 rounded-full text-xs font-medium ${
                          incident.status === 'active' ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'
                        }`}>
                          {incident.status || 'active'}
                        </span>
                      </TableCell>
                      <TableCell className="text-right">
                        <div className="flex items-center justify-end gap-2">
                          <Button
                            size="sm"
                            variant="ghost"
                            onClick={() => setSelectedIncident(incident.id)}
                          >
                            <Eye className="h-4 w-4" />
                          </Button>
                          {!incident.is_verified && (
                            <Button
                              size="sm"
                              variant="ghost"
                              onClick={() => moderateMutation.mutate({ id: incident.id, action: 'approve' })}
                              disabled={moderateMutation.isPending}
                            >
                              <CheckCircle className="h-4 w-4 text-green-600" />
                            </Button>
                          )}
                          <Button
                            size="sm"
                            variant="ghost"
                            onClick={() => moderateMutation.mutate({ id: incident.id, action: 'flag', reason: 'Flagged by admin' })}
                            disabled={moderateMutation.isPending}
                          >
                            <Flag className="h-4 w-4 text-orange-600" />
                          </Button>
                          <Button
                            size="sm"
                            variant="ghost"
                            onClick={() => {
                              if (confirm('Delete this incident?')) {
                                moderateMutation.mutate({ id: incident.id, action: 'delete' })
                              }
                            }}
                            disabled={moderateMutation.isPending}
                          >
                            <Trash2 className="h-4 w-4 text-red-600" />
                          </Button>
                        </div>
                      </TableCell>
                    </TableRow>
                  ))
                ) : (
                  <TableRow>
                    <TableCell colSpan={8} className="text-center py-8 text-gray-500">
                      No incidents found
                    </TableCell>
                  </TableRow>
                )}
              </TableBody>
            </Table>
          </div>

          {data?.pagination && (
            <div className="flex items-center justify-between mt-4">
              <div className="text-sm text-gray-600">
                Showing {((data.pagination.page - 1) * data.pagination.page_size) + 1} to{' '}
                {Math.min(data.pagination.page * data.pagination.page_size, data.pagination.total_count)} of{' '}
                {data.pagination.total_count} incidents
              </div>
              <div className="flex items-center gap-2">
                <Button
                  size="sm"
                  variant="outline"
                  onClick={() => handleFilterChange('page', filters.page! - 1)}
                  disabled={filters.page === 1}
                >
                  <ChevronLeft className="h-4 w-4" />
                  Previous
                </Button>
                <span className="text-sm text-gray-600">
                  Page {data.pagination.page} of {data.pagination.total_pages}
                </span>
                <Button
                  size="sm"
                  variant="outline"
                  onClick={() => handleFilterChange('page', filters.page! + 1)}
                  disabled={filters.page === data.pagination.total_pages}
                >
                  Next
                  <ChevronRight className="h-4 w-4" />
                </Button>
              </div>
            </div>
          )}
        </CardContent>
      </Card>

      {selectedIncident && (
        <IncidentDetailModal
          incidentId={selectedIncident}
          onClose={() => setSelectedIncident(null)}
        />
      )}
    </div>
  )
}
