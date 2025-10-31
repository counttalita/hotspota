import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { usersApi, type UserFilters } from '@/lib/api'
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
import {
  Search,
  Eye,
  ChevronLeft,
  ChevronRight,
  UserX,
  Ban,
  Crown,
} from 'lucide-react'
import { UserDetailModal } from '@/components/UserDetailModal'
import { toast } from 'sonner'

interface User {
  id: string
  phone_number: string
  is_premium: boolean
  premium_expires_at?: string
  alert_radius: number
  notification_config: Record<string, unknown>
  created_at: string
  updated_at: string
  is_suspended: boolean
  is_banned: boolean
}

export function UsersPage() {
  const queryClient = useQueryClient()
  const [filters, setFilters] = useState<UserFilters>({
    page: 1,
    page_size: 20,
    sort_by: 'inserted_at',
    sort_order: 'desc',
  })
  const [selectedUser, setSelectedUser] = useState<string | null>(null)

  const { data, isLoading } = useQuery({
    queryKey: ['users', filters],
    queryFn: () => usersApi.list(filters),
  })

  const suspendMutation = useMutation({
    mutationFn: ({ id, reason }: { id: string; reason?: string }) =>
      usersApi.suspend(id, reason),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['users'] })
      toast.success('User suspended successfully')
    },
    onError: () => {
      toast.error('Failed to suspend user')
    },
  })

  const banMutation = useMutation({
    mutationFn: ({ id, reason }: { id: string; reason?: string }) =>
      usersApi.ban(id, reason),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['users'] })
      toast.success('User banned successfully')
    },
    onError: () => {
      toast.error('Failed to ban user')
    },
  })

  const updatePremiumMutation = useMutation({
    mutationFn: ({ id, isPremium, expiresAt }: { id: string; isPremium: boolean; expiresAt?: string }) =>
      usersApi.updatePremium(id, isPremium, expiresAt),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['users'] })
      toast.success('Premium status updated successfully')
    },
    onError: () => {
      toast.error('Failed to update premium status')
    },
  })

  const handleFilterChange = (key: keyof UserFilters, value: string | number | undefined) => {
    setFilters((prev) => ({ ...prev, [key]: value, page: 1 }))
  }

  const handleSuspend = (userId: string) => {
    const reason = prompt('Enter suspension reason (optional):')
    if (reason !== null) {
      suspendMutation.mutate({ id: userId, reason: reason || undefined })
    }
  }

  const handleBan = (userId: string) => {
    const reason = prompt('Enter ban reason (optional):')
    if (reason !== null && confirm('Are you sure you want to ban this user?')) {
      banMutation.mutate({ id: userId, reason: reason || undefined })
    }
  }

  const handleTogglePremium = (userId: string, currentStatus: boolean) => {
    if (currentStatus) {
      // Revoke premium
      if (confirm('Revoke premium status for this user?')) {
        updatePremiumMutation.mutate({ id: userId, isPremium: false })
      }
    } else {
      // Grant premium
      const months = prompt('Grant premium for how many months? (1-12)', '1')
      if (months) {
        const monthsNum = parseInt(months, 10)
        if (monthsNum > 0 && monthsNum <= 12) {
          const expiresAt = new Date()
          expiresAt.setMonth(expiresAt.getMonth() + monthsNum)
          updatePremiumMutation.mutate({
            id: userId,
            isPremium: true,
            expiresAt: expiresAt.toISOString(),
          })
        } else {
          toast.error('Invalid number of months')
        }
      }
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

  const formatPhoneNumber = (phone: string) => {
    // Mask middle digits for privacy
    if (phone.length > 6) {
      return phone.slice(0, 3) + '****' + phone.slice(-3)
    }
    return phone
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold">User Management</h1>
          <p className="text-gray-600 mt-1">
            Manage user accounts and subscriptions
          </p>
        </div>
      </div>

      <Card>
        <CardHeader>
          <div className="flex flex-col md:flex-row gap-4">
            <div className="flex-1 relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-gray-400" />
              <Input
                placeholder="Search by phone number..."
                className="pl-10"
                value={filters.search || ''}
                onChange={(e) => handleFilterChange('search', e.target.value)}
              />
            </div>
            <Select
              value={filters.is_premium || 'all'}
              onValueChange={(value) => handleFilterChange('is_premium', value === 'all' ? undefined : value)}
            >
              <SelectTrigger className="w-[180px]">
                <SelectValue placeholder="Premium Status" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="all">All Users</SelectItem>
                <SelectItem value="true">Premium</SelectItem>
                <SelectItem value="false">Free</SelectItem>
              </SelectContent>
            </Select>
          </div>
        </CardHeader>
        <CardContent>
          <div className="rounded-md border">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Phone Number</TableHead>
                  <TableHead>Status</TableHead>
                  <TableHead>Premium</TableHead>
                  <TableHead>Alert Radius</TableHead>
                  <TableHead>Joined</TableHead>
                  <TableHead className="text-right">Actions</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {isLoading ? (
                  [...Array(5)].map((_, i) => (
                    <TableRow key={i}>
                      <TableCell colSpan={6}>
                        <div className="h-12 bg-gray-100 animate-pulse rounded" />
                      </TableCell>
                    </TableRow>
                  ))
                ) : data?.data && data.data.length > 0 ? (
                  data.data.map((user: User) => (
                    <TableRow key={user.id}>
                      <TableCell className="font-medium">
                        {formatPhoneNumber(user.phone_number)}
                      </TableCell>
                      <TableCell>
                        {user.is_banned ? (
                          <span className="px-2 py-1 rounded-full text-xs font-medium bg-red-100 text-red-800">
                            Banned
                          </span>
                        ) : user.is_suspended ? (
                          <span className="px-2 py-1 rounded-full text-xs font-medium bg-orange-100 text-orange-800">
                            Suspended
                          </span>
                        ) : (
                          <span className="px-2 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800">
                            Active
                          </span>
                        )}
                      </TableCell>
                      <TableCell>
                        <div className="flex items-center gap-2">
                          {user.is_premium ? (
                            <>
                              <Crown className="h-4 w-4 text-yellow-600" />
                              <span className="text-sm font-medium text-yellow-600">Premium</span>
                            </>
                          ) : (
                            <span className="text-sm text-gray-600">Free</span>
                          )}
                        </div>
                        {user.is_premium && user.premium_expires_at && (
                          <div className="text-xs text-gray-500 mt-1">
                            Expires: {new Date(user.premium_expires_at).toLocaleDateString()}
                          </div>
                        )}
                      </TableCell>
                      <TableCell className="text-sm text-gray-600">
                        {(user.alert_radius / 1000).toFixed(1)} km
                      </TableCell>
                      <TableCell className="text-sm text-gray-600">
                        {formatDate(user.created_at)}
                      </TableCell>
                      <TableCell className="text-right">
                        <div className="flex items-center justify-end gap-2">
                          <Button
                            size="sm"
                            variant="ghost"
                            onClick={() => setSelectedUser(user.id)}
                            title="View Details"
                          >
                            <Eye className="h-4 w-4" />
                          </Button>
                          {!user.is_banned && !user.is_suspended && (
                            <Button
                              size="sm"
                              variant="ghost"
                              onClick={() => handleSuspend(user.id)}
                              disabled={suspendMutation.isPending}
                              title="Suspend User"
                            >
                              <UserX className="h-4 w-4 text-orange-600" />
                            </Button>
                          )}
                          {!user.is_banned && (
                            <Button
                              size="sm"
                              variant="ghost"
                              onClick={() => handleBan(user.id)}
                              disabled={banMutation.isPending}
                              title="Ban User"
                            >
                              <Ban className="h-4 w-4 text-red-600" />
                            </Button>
                          )}
                          <Button
                            size="sm"
                            variant="ghost"
                            onClick={() => handleTogglePremium(user.id, user.is_premium)}
                            disabled={updatePremiumMutation.isPending}
                            title={user.is_premium ? 'Revoke Premium' : 'Grant Premium'}
                          >
                            <Crown className={`h-4 w-4 ${user.is_premium ? 'text-yellow-600' : 'text-gray-400'}`} />
                          </Button>
                        </div>
                      </TableCell>
                    </TableRow>
                  ))
                ) : (
                  <TableRow>
                    <TableCell colSpan={6} className="text-center py-8 text-gray-500">
                      No users found
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
                {data.pagination.total_count} users
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

      {selectedUser && (
        <UserDetailModal
          userId={selectedUser}
          onClose={() => setSelectedUser(null)}
        />
      )}
    </div>
  )
}
