import { useState } from 'react'
import { useQuery, useMutation } from '@tanstack/react-query'
import { usersApi } from '@/lib/api'
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import {
  User,
  Phone,
  Crown,
  MapPin,
  Calendar,
  Activity,
  Send,
  AlertTriangle,
  CheckCircle,
} from 'lucide-react'
import { toast } from 'sonner'

interface UserDetailModalProps {
  userId: string
  onClose: () => void
}

interface Location {
  latitude: number
  longitude: number
}

interface Incident {
  id: string
  type: string
  description?: string
  location: Location
  verification_count: number
  is_verified: boolean
  created_at: string
}

interface Verification {
  id: string
  incident_id: string
  created_at: string
}

interface NotificationConfig {
  suspended?: boolean
  suspended_at?: string
  suspended_by?: string
  suspension_reason?: string
  banned?: boolean
  banned_at?: string
  banned_by?: string
  ban_reason?: string
  [key: string]: unknown
}

interface UserDetail {
  id: string
  phone_number: string
  is_premium: boolean
  premium_expires_at?: string
  alert_radius: number
  notification_config: NotificationConfig
  created_at: string
  updated_at: string
  is_suspended: boolean
  is_banned: boolean
  incidents?: Incident[]
  verifications?: Verification[]
  incident_count: number
  verification_count: number
}

interface ActivityItem {
  id: string
  type: 'incident_reported' | 'incident_verified'
  description: string
  incident_type?: string
  incident_id?: string
  location?: Location
  created_at: string
}

export function UserDetailModal({ userId, onClose }: UserDetailModalProps) {
  const [notificationTitle, setNotificationTitle] = useState('')
  const [notificationMessage, setNotificationMessage] = useState('')

  const { data: userData, isLoading: userLoading } = useQuery({
    queryKey: ['user', userId],
    queryFn: () => usersApi.get(userId),
  })

  const { data: activityData, isLoading: activityLoading } = useQuery({
    queryKey: ['user-activity', userId],
    queryFn: () => usersApi.getActivity(userId),
  })

  const notifyMutation = useMutation({
    mutationFn: () => usersApi.notify(userId, notificationTitle, notificationMessage),
    onSuccess: () => {
      toast.success('Notification sent successfully')
      setNotificationTitle('')
      setNotificationMessage('')
    },
    onError: () => {
      toast.error('Failed to send notification')
    },
  })

  const handleSendNotification = () => {
    if (!notificationTitle.trim() || !notificationMessage.trim()) {
      toast.error('Please enter both title and message')
      return
    }
    notifyMutation.mutate()
  }

  const user = userData?.data as UserDetail | undefined

  const formatTimeAgo = (dateString: string) => {
    const date = new Date(dateString)
    const now = new Date()
    const diffMs = now.getTime() - date.getTime()
    const diffMins = Math.floor(diffMs / 60000)
    const diffHours = Math.floor(diffMs / 3600000)
    const diffDays = Math.floor(diffMs / 86400000)

    if (diffMins < 60) return `${diffMins}m ago`
    if (diffHours < 24) return `${diffHours}h ago`
    return `${diffDays}d ago`
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

  return (
    <Dialog open={true} onOpenChange={onClose}>
      <DialogContent className="max-w-4xl max-h-[90vh] overflow-y-auto">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <User className="h-5 w-5" />
            User Details
          </DialogTitle>
        </DialogHeader>

        {userLoading ? (
          <div className="space-y-4">
            {[...Array(3)].map((_, i) => (
              <div key={i} className="h-20 bg-gray-100 animate-pulse rounded" />
            ))}
          </div>
        ) : user ? (
          <Tabs defaultValue="overview" className="w-full">
            <TabsList className="grid w-full grid-cols-3">
              <TabsTrigger value="overview">Overview</TabsTrigger>
              <TabsTrigger value="activity">Activity</TabsTrigger>
              <TabsTrigger value="notify">Send Notification</TabsTrigger>
            </TabsList>

            <TabsContent value="overview" className="space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <Card>
                  <CardHeader>
                    <CardTitle className="text-sm font-medium flex items-center gap-2">
                      <Phone className="h-4 w-4" />
                      Phone Number
                    </CardTitle>
                  </CardHeader>
                  <CardContent>
                    <p className="text-lg font-semibold">{user.phone_number}</p>
                  </CardContent>
                </Card>

                <Card>
                  <CardHeader>
                    <CardTitle className="text-sm font-medium flex items-center gap-2">
                      <Crown className="h-4 w-4" />
                      Premium Status
                    </CardTitle>
                  </CardHeader>
                  <CardContent>
                    <div className="flex items-center gap-2">
                      {user.is_premium ? (
                        <>
                          <Crown className="h-5 w-5 text-yellow-600" />
                          <span className="text-lg font-semibold text-yellow-600">Premium</span>
                        </>
                      ) : (
                        <span className="text-lg font-semibold text-gray-600">Free</span>
                      )}
                    </div>
                    {user.is_premium && user.premium_expires_at && (
                      <p className="text-sm text-gray-500 mt-1">
                        Expires: {new Date(user.premium_expires_at).toLocaleDateString()}
                      </p>
                    )}
                  </CardContent>
                </Card>

                <Card>
                  <CardHeader>
                    <CardTitle className="text-sm font-medium flex items-center gap-2">
                      <MapPin className="h-4 w-4" />
                      Alert Radius
                    </CardTitle>
                  </CardHeader>
                  <CardContent>
                    <p className="text-lg font-semibold">{(user.alert_radius / 1000).toFixed(1)} km</p>
                  </CardContent>
                </Card>

                <Card>
                  <CardHeader>
                    <CardTitle className="text-sm font-medium flex items-center gap-2">
                      <Calendar className="h-4 w-4" />
                      Member Since
                    </CardTitle>
                  </CardHeader>
                  <CardContent>
                    <p className="text-lg font-semibold">
                      {new Date(user.created_at).toLocaleDateString()}
                    </p>
                  </CardContent>
                </Card>
              </div>

              <Card>
                <CardHeader>
                  <CardTitle className="text-sm font-medium">Account Status</CardTitle>
                </CardHeader>
                <CardContent className="space-y-2">
                  {user.is_banned && (
                    <div className="flex items-center gap-2 text-red-600">
                      <AlertTriangle className="h-4 w-4" />
                      <span className="font-medium">Account Banned</span>
                      {user.notification_config?.ban_reason && (
                        <span className="text-sm text-gray-600">
                          - {user.notification_config.ban_reason}
                        </span>
                      )}
                    </div>
                  )}
                  {user.is_suspended && (
                    <div className="flex items-center gap-2 text-orange-600">
                      <AlertTriangle className="h-4 w-4" />
                      <span className="font-medium">Account Suspended</span>
                      {user.notification_config?.suspension_reason && (
                        <span className="text-sm text-gray-600">
                          - {user.notification_config.suspension_reason}
                        </span>
                      )}
                    </div>
                  )}
                  {!user.is_banned && !user.is_suspended && (
                    <div className="flex items-center gap-2 text-green-600">
                      <CheckCircle className="h-4 w-4" />
                      <span className="font-medium">Account Active</span>
                    </div>
                  )}
                </CardContent>
              </Card>

              <Card>
                <CardHeader>
                  <CardTitle className="text-sm font-medium flex items-center gap-2">
                    <Activity className="h-4 w-4" />
                    Statistics
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <p className="text-sm text-gray-600">Incidents Reported</p>
                      <p className="text-2xl font-bold">{user.incident_count || 0}</p>
                    </div>
                    <div>
                      <p className="text-sm text-gray-600">Verifications Made</p>
                      <p className="text-2xl font-bold">{user.verification_count || 0}</p>
                    </div>
                  </div>
                </CardContent>
              </Card>

              {user.incidents && user.incidents.length > 0 && (
                <Card>
                  <CardHeader>
                    <CardTitle className="text-sm font-medium">Recent Incidents</CardTitle>
                  </CardHeader>
                  <CardContent>
                    <div className="space-y-2">
                      {user.incidents.slice(0, 5).map((incident) => (
                        <div
                          key={incident.id}
                          className="flex items-center justify-between p-3 border rounded-lg"
                        >
                          <div className="flex items-center gap-3">
                            <span className={`px-2 py-1 rounded-full text-xs font-medium ${getIncidentTypeColor(incident.type)}`}>
                              {incident.type}
                            </span>
                            <span className="text-sm text-gray-600">
                              {incident.description || 'No description'}
                            </span>
                          </div>
                          <div className="flex items-center gap-2 text-sm text-gray-500">
                            <span>{incident.verification_count} verifications</span>
                            <span>•</span>
                            <span>{formatTimeAgo(incident.created_at)}</span>
                          </div>
                        </div>
                      ))}
                    </div>
                  </CardContent>
                </Card>
              )}
            </TabsContent>

            <TabsContent value="activity" className="space-y-4">
              {activityLoading ? (
                <div className="space-y-2">
                  {[...Array(5)].map((_, i) => (
                    <div key={i} className="h-16 bg-gray-100 animate-pulse rounded" />
                  ))}
                </div>
              ) : activityData?.data && activityData.data.length > 0 ? (
                <Card>
                  <CardHeader>
                    <CardTitle className="text-sm font-medium">Activity Timeline</CardTitle>
                  </CardHeader>
                  <CardContent>
                    <div className="space-y-3">
                      {activityData.data.map((activity: ActivityItem) => (
                        <div
                          key={activity.id}
                          className="flex items-start gap-3 p-3 border rounded-lg"
                        >
                          <div className="mt-1">
                            {activity.type === 'incident_reported' ? (
                              <AlertTriangle className="h-5 w-5 text-orange-600" />
                            ) : (
                              <CheckCircle className="h-5 w-5 text-green-600" />
                            )}
                          </div>
                          <div className="flex-1">
                            <p className="font-medium">{activity.description}</p>
                            {activity.incident_type && (
                              <span className={`inline-block mt-1 px-2 py-1 rounded-full text-xs font-medium ${getIncidentTypeColor(activity.incident_type)}`}>
                                {activity.incident_type}
                              </span>
                            )}
                            {activity.location && (
                              <p className="text-xs text-gray-500 mt-1">
                                Location: {activity.location.latitude.toFixed(4)}, {activity.location.longitude.toFixed(4)}
                              </p>
                            )}
                          </div>
                          <div className="text-sm text-gray-500">
                            {formatTimeAgo(activity.created_at)}
                          </div>
                        </div>
                      ))}
                    </div>
                  </CardContent>
                </Card>
              ) : (
                <Card>
                  <CardContent className="py-8 text-center text-gray-500">
                    No activity found
                  </CardContent>
                </Card>
              )}
            </TabsContent>

            <TabsContent value="notify" className="space-y-4">
              <Card>
                <CardHeader>
                  <CardTitle className="text-sm font-medium flex items-center gap-2">
                    <Send className="h-4 w-4" />
                    Send Push Notification
                  </CardTitle>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div className="space-y-2">
                    <Label htmlFor="notification-title">Title</Label>
                    <Input
                      id="notification-title"
                      placeholder="Notification title"
                      value={notificationTitle}
                      onChange={(e) => setNotificationTitle(e.target.value)}
                    />
                  </div>
                  <div className="space-y-2">
                    <Label htmlFor="notification-message">Message</Label>
                    <textarea
                      id="notification-message"
                      placeholder="Notification message"
                      rows={4}
                      value={notificationMessage}
                      onChange={(e) => setNotificationMessage(e.target.value)}
                      className="flex min-h-[80px] w-full rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"
                    />
                  </div>
                  <Button
                    onClick={handleSendNotification}
                    disabled={notifyMutation.isPending || !notificationTitle.trim() || !notificationMessage.trim()}
                    className="w-full"
                  >
                    <Send className="h-4 w-4 mr-2" />
                    {notifyMutation.isPending ? 'Sending...' : 'Send Notification'}
                  </Button>
                </CardContent>
              </Card>
            </TabsContent>
          </Tabs>
        ) : (
          <div className="text-center py-8 text-gray-500">
            User not found
          </div>
        )}
      </DialogContent>
    </Dialog>
  )
}
