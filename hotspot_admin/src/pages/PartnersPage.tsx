import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { partnersApi, Partner, PartnerInput, PartnerStats } from '@/lib/api'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from '@/components/ui/card'
import { Badge } from '@/components/ui/badge'
import { Switch } from '@/components/ui/switch'
import { Plus, Edit, Trash2, TrendingUp, Eye, DollarSign } from 'lucide-react'
import { toast } from 'sonner'

export default function PartnersPage() {
  const queryClient = useQueryClient()
  const [page, setPage] = useState(1)
  const [pageSize] = useState(20)
  const [filters, setFilters] = useState({
    is_active: '',
    partner_type: '',
    search: '',
  })
  const [isCreateDialogOpen, setIsCreateDialogOpen] = useState(false)
  const [isEditDialogOpen, setIsEditDialogOpen] = useState(false)
  const [isStatsDialogOpen, setIsStatsDialogOpen] = useState(false)
  const [selectedPartner, setSelectedPartner] = useState<Partner | null>(null)
  const [formData, setFormData] = useState<PartnerInput>({
    name: '',
    logo_url: '',
    partner_type: 'insurance',
    service_regions: {},
    is_active: true,
    monthly_fee: 0,
    contract_start: '',
    contract_end: '',
    contact_email: '',
    contact_phone: '',
  })

  // Fetch partners
  const { data, isLoading } = useQuery({
    queryKey: ['partners', page, pageSize, filters],
    queryFn: () => partnersApi.list({ ...filters, page, page_size: pageSize }),
  })

  // Fetch partner stats
  const { data: statsData, isLoading: isLoadingStats } = useQuery({
    queryKey: ['partner-stats', selectedPartner?.id],
    queryFn: () => partnersApi.getStats(selectedPartner!.id),
    enabled: !!selectedPartner && isStatsDialogOpen,
  })

  // Create partner mutation
  const createMutation = useMutation({
    mutationFn: (data: PartnerInput) => partnersApi.create(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['partners'] })
      setIsCreateDialogOpen(false)
      resetForm()
      toast.success('Partner created successfully')
    },
    onError: (error: Error) => {
      toast.error(`Failed to create partner: ${error.message}`)
    },
  })

  // Update partner mutation
  const updateMutation = useMutation({
    mutationFn: ({ id, data }: { id: string; data: Partial<PartnerInput> }) =>
      partnersApi.update(id, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['partners'] })
      setIsEditDialogOpen(false)
      setSelectedPartner(null)
      resetForm()
      toast.success('Partner updated successfully')
    },
    onError: (error: Error) => {
      toast.error(`Failed to update partner: ${error.message}`)
    },
  })

  // Delete partner mutation
  const deleteMutation = useMutation({
    mutationFn: (id: string) => partnersApi.delete(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['partners'] })
      toast.success('Partner deleted successfully')
    },
    onError: (error: Error) => {
      toast.error(`Failed to delete partner: ${error.message}`)
    },
  })

  // Toggle active status mutation
  const toggleActiveMutation = useMutation({
    mutationFn: ({ id, isActive }: { id: string; isActive: boolean }) =>
      partnersApi.update(id, { is_active: isActive }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['partners'] })
      toast.success('Partner status updated')
    },
    onError: (error: Error) => {
      toast.error(`Failed to update status: ${error.message}`)
    },
  })

  const resetForm = () => {
    setFormData({
      name: '',
      logo_url: '',
      partner_type: 'insurance',
      service_regions: {},
      is_active: true,
      monthly_fee: 0,
      contract_start: '',
      contract_end: '',
      contact_email: '',
      contact_phone: '',
    })
  }

  const handleCreate = () => {
    createMutation.mutate(formData)
  }

  const handleEdit = (partner: Partner) => {
    setSelectedPartner(partner)
    setFormData({
      name: partner.name,
      logo_url: partner.logo_url || '',
      partner_type: partner.partner_type as PartnerInput['partner_type'],
      service_regions: partner.service_regions || {},
      is_active: partner.is_active,
      monthly_fee: partner.monthly_fee || 0,
      contract_start: partner.contract_start || '',
      contract_end: partner.contract_end || '',
      contact_email: partner.contact_email || '',
      contact_phone: partner.contact_phone || '',
    })
    setIsEditDialogOpen(true)
  }

  const handleUpdate = () => {
    if (selectedPartner) {
      updateMutation.mutate({ id: selectedPartner.id, data: formData })
    }
  }

  const handleDelete = (id: string) => {
    if (confirm('Are you sure you want to delete this partner?')) {
      deleteMutation.mutate(id)
    }
  }

  const handleToggleActive = (id: string, currentStatus: boolean) => {
    toggleActiveMutation.mutate({ id, isActive: !currentStatus })
  }

  const handleViewStats = (partner: Partner) => {
    setSelectedPartner(partner)
    setIsStatsDialogOpen(true)
  }

  const partners = data?.data || []
  const pagination = data?.pagination || { page: 1, page_size: 20, total_count: 0, total_pages: 1 }
  const stats = statsData?.data as PartnerStats | undefined

  return (
    <div className="p-6 space-y-6">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-3xl font-bold">Partner Management</h1>
          <p className="text-muted-foreground">
            Manage partner sponsorships and branded alerts
          </p>
        </div>
        <Button onClick={() => setIsCreateDialogOpen(true)}>
          <Plus className="mr-2 h-4 w-4" />
          Add Partner
        </Button>
      </div>

      {/* Filters */}
      <Card>
        <CardHeader>
          <CardTitle>Filters</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div>
              <Label>Search</Label>
              <Input
                placeholder="Search by name or email..."
                value={filters.search}
                onChange={(e) => setFilters({ ...filters, search: e.target.value })}
              />
            </div>
            <div>
              <Label>Status</Label>
              <Select
                value={filters.is_active}
                onValueChange={(value) => setFilters({ ...filters, is_active: value })}
              >
                <SelectTrigger>
                  <SelectValue placeholder="All statuses" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="">All statuses</SelectItem>
                  <SelectItem value="true">Active</SelectItem>
                  <SelectItem value="false">Inactive</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div>
              <Label>Partner Type</Label>
              <Select
                value={filters.partner_type}
                onValueChange={(value) => setFilters({ ...filters, partner_type: value })}
              >
                <SelectTrigger>
                  <SelectValue placeholder="All types" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="">All types</SelectItem>
                  <SelectItem value="insurance">Insurance</SelectItem>
                  <SelectItem value="security">Security</SelectItem>
                  <SelectItem value="roadside_assistance">Roadside Assistance</SelectItem>
                  <SelectItem value="other">Other</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* Partners Table */}
      <Card>
        <CardHeader>
          <CardTitle>Partners ({pagination.total_count})</CardTitle>
          <CardDescription>
            Showing {partners.length} of {pagination.total_count} partners
          </CardDescription>
        </CardHeader>
        <CardContent>
          {isLoading ? (
            <div className="text-center py-8">Loading partners...</div>
          ) : partners.length === 0 ? (
            <div className="text-center py-8 text-muted-foreground">
              No partners found. Create your first partner to get started.
            </div>
          ) : (
            <>
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Name</TableHead>
                    <TableHead>Type</TableHead>
                    <TableHead>Contact</TableHead>
                    <TableHead>Monthly Fee</TableHead>
                    <TableHead>Contract</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead className="text-right">Actions</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {partners.map((partner: Partner) => (
                    <TableRow key={partner.id}>
                      <TableCell>
                        <div className="flex items-center gap-3">
                          {partner.logo_url && (
                            <img
                              src={partner.logo_url}
                              alt={partner.name}
                              className="w-10 h-10 rounded object-cover"
                            />
                          )}
                          <div>
                            <div className="font-medium">{partner.name}</div>
                            <div className="text-sm text-muted-foreground">
                              {partner.id.slice(0, 8)}
                            </div>
                          </div>
                        </div>
                      </TableCell>
                      <TableCell>
                        <Badge variant="outline">
                          {partner.partner_type.replace('_', ' ')}
                        </Badge>
                      </TableCell>
                      <TableCell>
                        <div className="text-sm">
                          {partner.contact_email && (
                            <div>{partner.contact_email}</div>
                          )}
                          {partner.contact_phone && (
                            <div className="text-muted-foreground">
                              {partner.contact_phone}
                            </div>
                          )}
                        </div>
                      </TableCell>
                      <TableCell>
                        {partner.monthly_fee ? (
                          <div className="flex items-center gap-1">
                            <DollarSign className="h-4 w-4" />
                            {partner.monthly_fee}
                          </div>
                        ) : (
                          <span className="text-muted-foreground">-</span>
                        )}
                      </TableCell>
                      <TableCell>
                        {partner.contract_start && partner.contract_end ? (
                          <div className="text-sm">
                            <div>{new Date(partner.contract_start).toLocaleDateString()}</div>
                            <div className="text-muted-foreground">
                              to {new Date(partner.contract_end).toLocaleDateString()}
                            </div>
                          </div>
                        ) : (
                          <span className="text-muted-foreground">-</span>
                        )}
                      </TableCell>
                      <TableCell>
                        <div className="flex items-center gap-2">
                          <Switch
                            checked={partner.is_active}
                            onCheckedChange={() =>
                              handleToggleActive(partner.id, partner.is_active)
                            }
                          />
                          <Badge variant={partner.is_active ? 'default' : 'secondary'}>
                            {partner.is_active ? 'Active' : 'Inactive'}
                          </Badge>
                        </div>
                      </TableCell>
                      <TableCell className="text-right">
                        <div className="flex justify-end gap-2">
                          <Button
                            variant="ghost"
                            size="sm"
                            onClick={() => handleViewStats(partner)}
                          >
                            <TrendingUp className="h-4 w-4" />
                          </Button>
                          <Button
                            variant="ghost"
                            size="sm"
                            onClick={() => handleEdit(partner)}
                          >
                            <Edit className="h-4 w-4" />
                          </Button>
                          <Button
                            variant="ghost"
                            size="sm"
                            onClick={() => handleDelete(partner.id)}
                          >
                            <Trash2 className="h-4 w-4 text-destructive" />
                          </Button>
                        </div>
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>

              {/* Pagination */}
              <div className="flex items-center justify-between mt-4">
                <div className="text-sm text-muted-foreground">
                  Page {pagination.page} of {pagination.total_pages}
                </div>
                <div className="flex gap-2">
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => setPage(page - 1)}
                    disabled={page === 1}
                  >
                    Previous
                  </Button>
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => setPage(page + 1)}
                    disabled={page >= pagination.total_pages}
                  >
                    Next
                  </Button>
                </div>
              </div>
            </>
          )}
        </CardContent>
      </Card>

      {/* Create Partner Dialog */}
      <Dialog open={isCreateDialogOpen} onOpenChange={setIsCreateDialogOpen}>
        <DialogContent className="max-w-2xl max-h-[90vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>Add New Partner</DialogTitle>
            <DialogDescription>
              Create a new partner for sponsored alerts and branded content.
            </DialogDescription>
          </DialogHeader>
          <div className="grid gap-4 py-4">
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="name">Partner Name *</Label>
                <Input
                  id="name"
                  value={formData.name}
                  onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                  placeholder="Acme Insurance"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="partner_type">Partner Type *</Label>
                <Select
                  value={formData.partner_type}
                  onValueChange={(value) =>
                    setFormData({ ...formData, partner_type: value as PartnerInput['partner_type'] })
                  }
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="insurance">Insurance</SelectItem>
                    <SelectItem value="security">Security</SelectItem>
                    <SelectItem value="roadside_assistance">Roadside Assistance</SelectItem>
                    <SelectItem value="other">Other</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </div>

            <div className="space-y-2">
              <Label htmlFor="logo_url">Logo URL</Label>
              <Input
                id="logo_url"
                value={formData.logo_url}
                onChange={(e) => setFormData({ ...formData, logo_url: e.target.value })}
                placeholder="https://example.com/logo.png"
              />
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="contact_email">Contact Email</Label>
                <Input
                  id="contact_email"
                  type="email"
                  value={formData.contact_email}
                  onChange={(e) => setFormData({ ...formData, contact_email: e.target.value })}
                  placeholder="contact@partner.com"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="contact_phone">Contact Phone</Label>
                <Input
                  id="contact_phone"
                  value={formData.contact_phone}
                  onChange={(e) => setFormData({ ...formData, contact_phone: e.target.value })}
                  placeholder="+1234567890"
                />
              </div>
            </div>

            <div className="space-y-2">
              <Label htmlFor="monthly_fee">Monthly Fee</Label>
              <Input
                id="monthly_fee"
                type="number"
                value={formData.monthly_fee}
                onChange={(e) =>
                  setFormData({ ...formData, monthly_fee: parseFloat(e.target.value) || 0 })
                }
                placeholder="0.00"
              />
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="contract_start">Contract Start</Label>
                <Input
                  id="contract_start"
                  type="date"
                  value={formData.contract_start}
                  onChange={(e) => setFormData({ ...formData, contract_start: e.target.value })}
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="contract_end">Contract End</Label>
                <Input
                  id="contract_end"
                  type="date"
                  value={formData.contract_end}
                  onChange={(e) => setFormData({ ...formData, contract_end: e.target.value })}
                />
              </div>
            </div>

            <div className="flex items-center space-x-2">
              <Switch
                id="is_active"
                checked={formData.is_active}
                onCheckedChange={(checked) => setFormData({ ...formData, is_active: checked })}
              />
              <Label htmlFor="is_active">Active</Label>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setIsCreateDialogOpen(false)}>
              Cancel
            </Button>
            <Button onClick={handleCreate} disabled={createMutation.isPending}>
              {createMutation.isPending ? 'Creating...' : 'Create Partner'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Edit Partner Dialog */}
      <Dialog open={isEditDialogOpen} onOpenChange={setIsEditDialogOpen}>
        <DialogContent className="max-w-2xl max-h-[90vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>Edit Partner</DialogTitle>
            <DialogDescription>
              Update partner information and settings.
            </DialogDescription>
          </DialogHeader>
          <div className="grid gap-4 py-4">
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="edit_name">Partner Name *</Label>
                <Input
                  id="edit_name"
                  value={formData.name}
                  onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                  placeholder="Acme Insurance"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="edit_partner_type">Partner Type *</Label>
                <Select
                  value={formData.partner_type}
                  onValueChange={(value) =>
                    setFormData({ ...formData, partner_type: value as PartnerInput['partner_type'] })
                  }
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="insurance">Insurance</SelectItem>
                    <SelectItem value="security">Security</SelectItem>
                    <SelectItem value="roadside_assistance">Roadside Assistance</SelectItem>
                    <SelectItem value="other">Other</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </div>

            <div className="space-y-2">
              <Label htmlFor="edit_logo_url">Logo URL</Label>
              <Input
                id="edit_logo_url"
                value={formData.logo_url}
                onChange={(e) => setFormData({ ...formData, logo_url: e.target.value })}
                placeholder="https://example.com/logo.png"
              />
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="edit_contact_email">Contact Email</Label>
                <Input
                  id="edit_contact_email"
                  type="email"
                  value={formData.contact_email}
                  onChange={(e) => setFormData({ ...formData, contact_email: e.target.value })}
                  placeholder="contact@partner.com"
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="edit_contact_phone">Contact Phone</Label>
                <Input
                  id="edit_contact_phone"
                  value={formData.contact_phone}
                  onChange={(e) => setFormData({ ...formData, contact_phone: e.target.value })}
                  placeholder="+1234567890"
                />
              </div>
            </div>

            <div className="space-y-2">
              <Label htmlFor="edit_monthly_fee">Monthly Fee</Label>
              <Input
                id="edit_monthly_fee"
                type="number"
                value={formData.monthly_fee}
                onChange={(e) =>
                  setFormData({ ...formData, monthly_fee: parseFloat(e.target.value) || 0 })
                }
                placeholder="0.00"
              />
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="edit_contract_start">Contract Start</Label>
                <Input
                  id="edit_contract_start"
                  type="date"
                  value={formData.contract_start}
                  onChange={(e) => setFormData({ ...formData, contract_start: e.target.value })}
                />
              </div>
              <div className="space-y-2">
                <Label htmlFor="edit_contract_end">Contract End</Label>
                <Input
                  id="edit_contract_end"
                  type="date"
                  value={formData.contract_end}
                  onChange={(e) => setFormData({ ...formData, contract_end: e.target.value })}
                />
              </div>
            </div>

            <div className="flex items-center space-x-2">
              <Switch
                id="edit_is_active"
                checked={formData.is_active}
                onCheckedChange={(checked) => setFormData({ ...formData, is_active: checked })}
              />
              <Label htmlFor="edit_is_active">Active</Label>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setIsEditDialogOpen(false)}>
              Cancel
            </Button>
            <Button onClick={handleUpdate} disabled={updateMutation.isPending}>
              {updateMutation.isPending ? 'Updating...' : 'Update Partner'}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Partner Stats Dialog */}
      <Dialog open={isStatsDialogOpen} onOpenChange={setIsStatsDialogOpen}>
        <DialogContent className="max-w-2xl">
          <DialogHeader>
            <DialogTitle>Partner Performance</DialogTitle>
            <DialogDescription>
              {selectedPartner?.name} - Last 30 days
            </DialogDescription>
          </DialogHeader>
          {isLoadingStats ? (
            <div className="text-center py-8">Loading statistics...</div>
          ) : stats ? (
            <div className="grid gap-4 py-4">
              <div className="grid grid-cols-2 gap-4">
                <Card>
                  <CardHeader className="pb-2">
                    <CardTitle className="text-sm font-medium">Total Impressions</CardTitle>
                  </CardHeader>
                  <CardContent>
                    <div className="flex items-center gap-2">
                      <Eye className="h-4 w-4 text-muted-foreground" />
                      <div className="text-2xl font-bold">{stats.total_impressions}</div>
                    </div>
                  </CardContent>
                </Card>

                <Card>
                  <CardHeader className="pb-2">
                    <CardTitle className="text-sm font-medium">Total Clicks</CardTitle>
                  </CardHeader>
                  <CardContent>
                    <div className="flex items-center gap-2">
                      <TrendingUp className="h-4 w-4 text-muted-foreground" />
                      <div className="text-2xl font-bold">{stats.total_clicks}</div>
                    </div>
                  </CardContent>
                </Card>

                <Card>
                  <CardHeader className="pb-2">
                    <CardTitle className="text-sm font-medium">Click-Through Rate</CardTitle>
                  </CardHeader>
                  <CardContent>
                    <div className="text-2xl font-bold">{stats.click_through_rate}%</div>
                  </CardContent>
                </Card>

                <Card>
                  <CardHeader className="pb-2">
                    <CardTitle className="text-sm font-medium">Total Alerts</CardTitle>
                  </CardHeader>
                  <CardContent>
                    <div className="text-2xl font-bold">{stats.total_alerts}</div>
                  </CardContent>
                </Card>
              </div>

              <Card>
                <CardHeader>
                  <CardTitle>Revenue</CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="space-y-2">
                    <div className="flex justify-between">
                      <span className="text-muted-foreground">Monthly Fee:</span>
                      <span className="font-medium">${stats.monthly_fee}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-muted-foreground">Period Revenue:</span>
                      <span className="font-bold text-lg">${stats.revenue}</span>
                    </div>
                  </div>
                </CardContent>
              </Card>
            </div>
          ) : (
            <div className="text-center py-8 text-muted-foreground">
              No statistics available
            </div>
          )}
          <DialogFooter>
            <Button onClick={() => setIsStatsDialogOpen(false)}>Close</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  )
}
