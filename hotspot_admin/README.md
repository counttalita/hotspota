# Hotspot Admin Portal

Mobile-friendly web application for moderating incidents, managing users, and viewing analytics.

## 🏗️ Architecture

- **Framework**: React 18 with Vite
- **Routing**: React Router 6
- **State Management**: Zustand
- **Server State**: React Query (TanStack Query)
- **Styling**: TailwindCSS
- **UI Components**: shadcn/ui
- **Charts**: Recharts
- **Tables**: TanStack Table
- **Forms**: React Hook Form + Zod validation
- **Maps**: React Map GL with MapLibre
- **Authentication**: JWT tokens
- **API Client**: Axios

## 📱 Features

### Admin Dashboard

- **Overview Stats** - Total incidents, active users, hotspot zones, verification rate
- **Real-time Activity Feed** - Live incident reports as they come in
- **Geographic Distribution** - Map view of all incidents and hotspot zones
- **Quick Actions** - Moderate, verify, or delete incidents

### Incident Management

- **Incident List** - Paginated table with filtering and sorting
- **Incident Details** - Full incident information with map location
- **Moderation Tools** - Approve, flag, or delete incidents
- **Bulk Actions** - Select multiple incidents for batch operations
- **Photo Review** - View and moderate uploaded photos
- **User Reports** - See who reported each incident

### User Management

- **User List** - All registered users with search and filters
- **User Details** - Profile, incident history, verification stats
- **Account Actions** - Suspend, ban, or promote users
- **Premium Management** - View and manage subscriptions
- **Activity Logs** - Track user actions and behavior

### Hotspot Zone Management

- **Zone List** - All active and dissolved hotspot zones
- **Zone Details** - Incidents within zone, risk level, creation date
- **Manual Zone Creation** - Create custom hotspot zones
- **Zone Editing** - Adjust radius, risk level, or dissolve zones
- **Zone Analytics** - Entry/exit statistics, affected users

### Partner & Monetization

- **Partner Management** - Add, edit, or remove sponsorship partners
- **Sponsored Alerts** - View and manage branded incident verifications
- **Impression Tracking** - Analytics for sponsored content
- **Enterprise Clients** - Manage B2B subscriptions and API access
- **Revenue Dashboard** - Subscription and partnership revenue metrics

### Analytics & Reports

- **Incident Trends** - Time-series charts of incident reports
- **Geographic Heatmap** - Density visualization of incidents
- **Peak Hours Analysis** - When incidents occur most frequently
- **User Engagement** - Active users, retention, verification rates
- **Export Reports** - Download data as CSV or PDF

### System Settings

- **Admin Users** - Manage admin accounts and permissions
- **Notification Templates** - Customize push notification messages
- **Rate Limits** - Configure API and reporting rate limits
- **Feature Flags** - Enable/disable features for testing
- **Audit Logs** - System-wide activity tracking

## 🚀 Getting Started

### Prerequisites

- Node.js 20.x or higher
- npm or yarn
- Access to Hotspot backend API

### Installation

1. **Install dependencies**
   ```bash
   cd hotspot_admin
   npm install
   ```

2. **Configure environment variables**
   ```bash
   cp .env.example .env
   ```

   Edit `.env`:
   ```bash
   VITE_API_URL=http://localhost:4000/api
   VITE_WS_URL=ws://localhost:4000/socket
   VITE_MAPLIBRE_STYLE_URL=https://tiles.example.com/style.json
   ```

3. **Start development server**
   ```bash
   npm run dev
   ```

   The admin portal will be available at [`http://localhost:5173`](http://localhost:5173)

4. **Build for production**
   ```bash
   npm run build
   ```

   Output will be in the `dist/` directory.

## 📂 Project Structure

```
hotspot_admin/
├── src/
│   ├── components/          # Reusable components
│   │   ├── ui/             # shadcn/ui components
│   │   ├── layout/         # Layout components
│   │   ├── incidents/      # Incident-related components
│   │   ├── users/          # User management components
│   │   ├── zones/          # Hotspot zone components
│   │   ├── charts/         # Chart components
│   │   └── tables/         # Table components
│   ├── pages/              # Page components
│   │   ├── Dashboard.tsx
│   │   ├── Incidents.tsx
│   │   ├── Users.tsx
│   │   ├── Zones.tsx
│   │   ├── Partners.tsx
│   │   ├── Analytics.tsx
│   │   └── Settings.tsx
│   ├── hooks/              # Custom React hooks
│   │   ├── useIncidents.ts
│   │   ├── useUsers.ts
│   │   ├── useZones.ts
│   │   └── useAuth.ts
│   ├── services/           # API services
│   │   ├── api.ts
│   │   ├── incidents.ts
│   │   ├── users.ts
│   │   ├── zones.ts
│   │   └── analytics.ts
│   ├── stores/             # Zustand stores
│   │   ├── authStore.ts
│   │   ├── incidentStore.ts
│   │   └── settingsStore.ts
│   ├── utils/              # Utility functions
│   │   ├── formatting.ts
│   │   ├── validation.ts
│   │   └── permissions.ts
│   ├── types/              # TypeScript types
│   │   ├── incident.ts
│   │   ├── user.ts
│   │   └── zone.ts
│   ├── App.tsx             # Root component
│   ├── main.tsx            # Entry point
│   └── router.tsx          # Route configuration
├── public/                 # Static assets
├── index.html              # HTML template
├── vite.config.ts          # Vite configuration
├── tailwind.config.js      # Tailwind configuration
├── tsconfig.json           # TypeScript configuration
└── package.json            # Dependencies
```

## 🎨 Key Pages

### Dashboard
- Overview cards (total incidents, users, zones, revenue)
- Real-time activity feed
- Geographic distribution map
- Quick stats and trends

### Incidents Page
- Searchable, filterable table
- Columns: Type, Location, Time, Reporter, Status, Verifications
- Actions: View, Moderate, Delete
- Bulk selection and actions
- Export to CSV

### Users Page
- User list with search and filters
- User details modal
- Account actions (suspend, ban, promote)
- Premium subscription management
- Activity history

### Zones Page
- List of all hotspot zones
- Map view with zone overlays
- Zone details: incidents, risk level, stats
- Create/edit/dissolve zones
- Entry/exit analytics

### Partners Page
- Partner list with logos
- Add/edit partner information
- Service region configuration
- Sponsored alert management
- Impression and click metrics

### Analytics Page
- Incident trends over time
- Geographic heatmap
- Peak hours by incident type
- User engagement metrics
- Export reports

## 🔐 Authentication

### Admin Login
```typescript
// services/auth.ts
export const login = async (email: string, password: string) => {
  const response = await api.post('/admin/auth/login', {
    email,
    password,
  });
  
  const { token, admin } = response.data;
  
  // Store token
  localStorage.setItem('admin_token', token);
  
  return admin;
};
```

### Protected Routes
```typescript
// router.tsx
import { Navigate } from 'react-router-dom';
import { useAuthStore } from './stores/authStore';

const ProtectedRoute = ({ children }) => {
  const { isAuthenticated } = useAuthStore();
  
  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }
  
  return children;
};
```

### Permission Levels
- **Super Admin** - Full access to all features
- **Moderator** - Incident moderation and user management
- **Analyst** - Read-only access to analytics
- **Partner Manager** - Manage partnerships and sponsored content

## 📊 Data Tables

### Example: Incident Table
```typescript
import { useReactTable, getCoreRowModel } from '@tanstack/react-table';

const columns = [
  { accessorKey: 'type', header: 'Type' },
  { accessorKey: 'location', header: 'Location' },
  { accessorKey: 'createdAt', header: 'Time' },
  { accessorKey: 'reporter', header: 'Reporter' },
  { accessorKey: 'verificationCount', header: 'Verifications' },
  { accessorKey: 'status', header: 'Status' },
];

const IncidentTable = ({ data }) => {
  const table = useReactTable({
    data,
    columns,
    getCoreRowModel: getCoreRowModel(),
  });

  return (
    <table className="w-full">
      {/* Table implementation */}
    </table>
  );
};
```

## 📈 Charts & Visualizations

### Incident Trends Chart
```typescript
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip } from 'recharts';

const IncidentTrendsChart = ({ data }) => {
  return (
    <LineChart width={800} height={400} data={data}>
      <CartesianGrid strokeDasharray="3 3" />
      <XAxis dataKey="date" />
      <YAxis />
      <Tooltip />
      <Line type="monotone" dataKey="hijackings" stroke="#FF3B30" />
      <Line type="monotone" dataKey="muggings" stroke="#FF9500" />
      <Line type="monotone" dataKey="accidents" stroke="#007AFF" />
    </LineChart>
  );
};
```

## 🗺️ Map Integration

### Admin Map View
```typescript
import Map, { Source, Layer } from 'react-map-gl';
import 'maplibre-gl/dist/maplibre-gl.css';

const AdminMap = ({ incidents, zones }) => {
  return (
    <Map
      mapLib={maplibregl}
      initialViewState={{
        longitude: 28.0473,
        latitude: -26.2041,
        zoom: 10,
      }}
      style={{ width: '100%', height: '600px' }}
      mapStyle={process.env.VITE_MAPLIBRE_STYLE_URL}
    >
      {/* Incident markers */}
      {incidents.map(incident => (
        <Marker
          key={incident.id}
          longitude={incident.location.longitude}
          latitude={incident.location.latitude}
          color={getIncidentColor(incident.type)}
        />
      ))}
      
      {/* Hotspot zones */}
      {zones.map(zone => (
        <Source key={zone.id} type="geojson" data={zone.geometry}>
          <Layer
            type="fill"
            paint={{
              'fill-color': getZoneColor(zone.riskLevel),
              'fill-opacity': 0.3,
            }}
          />
        </Source>
      ))}
    </Map>
  );
};
```

## 📱 Mobile Responsiveness

The admin portal is fully responsive and optimized for:
- **Desktop** (1920x1080 and above)
- **Laptop** (1366x768)
- **Tablet** (768x1024)
- **Mobile** (375x667 and above)

### Responsive Design Patterns
- Collapsible sidebar on mobile
- Stacked cards instead of tables on small screens
- Touch-friendly buttons and controls
- Simplified navigation menu
- Bottom sheet modals on mobile

## 🧪 Testing

```bash
# Run unit tests
npm test

# Run tests with coverage
npm test -- --coverage

# Run E2E tests
npm run test:e2e

# Run tests in watch mode
npm test -- --watch
```

## 🚢 Deployment

### Build for Production
```bash
npm run build
```

### Deploy to Vercel
```bash
npm install -g vercel
vercel --prod
```

### Deploy to Netlify
```bash
npm install -g netlify-cli
netlify deploy --prod --dir=dist
```

### Environment Variables (Production)
```bash
VITE_API_URL=https://api.hotspot.app/api
VITE_WS_URL=wss://api.hotspot.app/socket
VITE_MAPLIBRE_STYLE_URL=https://tiles.hotspot.app/style.json
```

## 🔒 Security

- JWT token authentication with refresh
- Role-based access control (RBAC)
- API request signing
- CSRF protection
- XSS prevention
- Content Security Policy (CSP)
- Rate limiting on admin actions
- Audit logging for all admin actions

## 🐛 Debugging

```bash
# Development mode with source maps
npm run dev

# Check bundle size
npm run build -- --analyze

# Lint code
npm run lint

# Format code
npm run format
```

## 📚 Additional Resources

- [React Documentation](https://react.dev/)
- [Vite Guide](https://vitejs.dev/guide/)
- [TailwindCSS Docs](https://tailwindcss.com/docs)
- [shadcn/ui Components](https://ui.shadcn.com/)
- [React Query Docs](https://tanstack.com/query/latest)
- [Recharts Examples](https://recharts.org/en-US/examples)

## 🤝 Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md) in the root directory.

## 📄 License

MIT License - see [LICENSE](../LICENSE) file for details.
