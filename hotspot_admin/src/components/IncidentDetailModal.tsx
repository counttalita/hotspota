import { useQuery } from '@tanstack/react-query'
import { incidentsApi } from '@/lib/api'
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { Badge } from '@/components/ui/badge'
import { MapPin, User, Clock, CheckCircle, Image as ImageIcon } from 'lucide-react'
import { useState } from 'react'

interface IncidentDetailModalProps {
  incidentId: string
  onClose: () => void
}

interface Verification {
  id: string
  user_id: string
  created_at: string
}

interface FlaggedContent {
  id: string
  content_type: string
  flag_reason: string
  status: string
  created_at: string
}

export function IncidentDetailModal({ incidentId, onClose }: IncidentDetailModalProps) {
  const [showPhotoLightbox, setShowPhotoLightbox] = useState(false)

  const { data, isLoading } = useQuery({
    queryKey: ['incident', incidentId],
    queryFn: () => incidentsApi.get(incidentId),
  })

  const incident = data?.data

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
      month: 'long',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    })
  }

  return (
    <>
      <Dialog open={true} onOpenChange={onClose}>
        <DialogContent className="max-w-3xl max-h-[90vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>Incident Details</DialogTitle>
          </DialogHeader>

          {isLoading ? (
            <div className="space-y-4">
              <div className="h-8 bg-gray-200 animate-pulse rounded" />
              <div className="h-32 bg-gray-200 animate-pulse rounded" />
              <div className="h-64 bg-gray-200 animate-pulse rounded" />
            </div>
          ) : incident ? (
            <div className="space-y-6">
              <div className="flex items-center gap-3">
                <Badge className={getIncidentTypeColor(incident.type)}>
                  {incident.type}
                </Badge>
                {incident.is_verified && (
                  <Badge className="bg-green-100 text-green-800">
                    <CheckCircle className="h-3 w-3 mr-1" />
                    Verified
                  </Badge>
                )}
                <Badge className={incident.status === 'active' ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'}>
                  {incident.status || 'active'}
                </Badge>
              </div>

              <div className="space-y-4">
                <div>
                  <h3 className="text-sm font-medium text-gray-500 mb-1">Description</h3>
                  <p className="text-gray-900">
                    {incident.description || 'No description provided'}
                  </p>
                </div>

                {incident.photo_url && (
                  <div>
                    <h3 className="text-sm font-medium text-gray-500 mb-2">Photo</h3>
                    <div
                      className="relative w-full h-64 bg-gray-100 rounded-lg overflow-hidden cursor-pointer hover:opacity-90 transition-opacity"
                      onClick={() => setShowPhotoLightbox(true)}
                    >
                      <img
                        src={incident.photo_url}
                        alt="Incident photo"
                        className="w-full h-full object-cover"
                      />
                      <div className="absolute inset-0 flex items-center justify-center bg-black bg-opacity-0 hover:bg-opacity-10 transition-all">
                        <ImageIcon className="h-8 w-8 text-white opacity-0 hover:opacity-100" />
                      </div>
                    </div>
                  </div>
                )}

                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <h3 className="text-sm font-medium text-gray-500 mb-1 flex items-center">
                      <User className="h-4 w-4 mr-1" />
                      Reported By
                    </h3>
                    <p className="text-gray-900">
                      {incident.user?.phone_number || 'Unknown'}
                    </p>
                    {incident.user?.is_premium && (
                      <Badge className="mt-1 bg-purple-100 text-purple-800">Premium</Badge>
                    )}
                  </div>

                  <div>
                    <h3 className="text-sm font-medium text-gray-500 mb-1 flex items-center">
                      <CheckCircle className="h-4 w-4 mr-1" />
                      Verifications
                    </h3>
                    <p className="text-gray-900">
                      {incident.verification_count} {incident.verification_count === 1 ? 'verification' : 'verifications'}
                    </p>
                  </div>

                  <div>
                    <h3 className="text-sm font-medium text-gray-500 mb-1 flex items-center">
                      <Clock className="h-4 w-4 mr-1" />
                      Created
                    </h3>
                    <p className="text-gray-900 text-sm">
                      {formatDate(incident.created_at)}
                    </p>
                  </div>

                  <div>
                    <h3 className="text-sm font-medium text-gray-500 mb-1 flex items-center">
                      <Clock className="h-4 w-4 mr-1" />
                      Expires
                    </h3>
                    <p className="text-gray-900 text-sm">
                      {formatDate(incident.expires_at)}
                    </p>
                  </div>
                </div>

                <div>
                  <h3 className="text-sm font-medium text-gray-500 mb-1 flex items-center">
                    <MapPin className="h-4 w-4 mr-1" />
                    Location
                  </h3>
                  <p className="text-gray-900 text-sm">
                    {incident.location?.latitude.toFixed(6)}, {incident.location?.longitude.toFixed(6)}
                  </p>
                  <div className="mt-2 w-full h-64 bg-gray-100 rounded-lg overflow-hidden">
                    <iframe
                      width="100%"
                      height="100%"
                      frameBorder="0"
                      src={`https://www.openstreetmap.org/export/embed.html?bbox=${incident.location?.longitude - 0.01},${incident.location?.latitude - 0.01},${incident.location?.longitude + 0.01},${incident.location?.latitude + 0.01}&layer=mapnik&marker=${incident.location?.latitude},${incident.location?.longitude}`}
                    />
                  </div>
                </div>

                {incident.verifications && incident.verifications.length > 0 && (
                  <div>
                    <h3 className="text-sm font-medium text-gray-500 mb-2">Verification History</h3>
                    <div className="space-y-2">
                      {incident.verifications.map((verification: Verification) => (
                        <div key={verification.id} className="flex items-center justify-between p-2 bg-gray-50 rounded">
                          <span className="text-sm text-gray-600">User verified</span>
                          <span className="text-xs text-gray-500">
                            {formatDate(verification.created_at)}
                          </span>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                {incident.flagged_content && incident.flagged_content.length > 0 && (
                  <div>
                    <h3 className="text-sm font-medium text-gray-500 mb-2">Flagged Content</h3>
                    <div className="space-y-2">
                      {incident.flagged_content.map((flag: FlaggedContent) => (
                        <div key={flag.id} className="p-3 bg-orange-50 border border-orange-200 rounded">
                          <div className="flex items-center justify-between mb-1">
                            <span className="text-sm font-medium text-orange-900">{flag.flag_reason}</span>
                            <Badge className={
                              flag.status === 'pending' ? 'bg-yellow-100 text-yellow-800' :
                              flag.status === 'approved' ? 'bg-green-100 text-green-800' :
                              'bg-red-100 text-red-800'
                            }>
                              {flag.status}
                            </Badge>
                          </div>
                          <span className="text-xs text-gray-600">
                            {formatDate(flag.created_at)}
                          </span>
                        </div>
                      ))}
                    </div>
                  </div>
                )}
              </div>
            </div>
          ) : (
            <div className="text-center py-8 text-gray-500">
              Incident not found
            </div>
          )}
        </DialogContent>
      </Dialog>

      {showPhotoLightbox && incident?.photo_url && (
        <Dialog open={true} onOpenChange={() => setShowPhotoLightbox(false)}>
          <DialogContent className="max-w-5xl">
            <img
              src={incident.photo_url}
              alt="Incident photo"
              className="w-full h-auto"
            />
          </DialogContent>
        </Dialog>
      )}
    </>
  )
}
