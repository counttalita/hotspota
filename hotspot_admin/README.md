# Hotspot Admin Portal

Web-based administration portal for the Hotspot safety reporting platform. Built with React, TypeScript, Vite, and TailwindCSS.

## Features

- 📊 **Dashboard**: Real-time statistics and activity monitoring
- 🚨 **Incident Management**: Review, moderate, and manage incident reports
- 👥 **User Management**: Manage user accounts, subscriptions, and permissions
- 🗺️ **Zone Management**: Create and manage hotspot zones
- 📈 **Analytics**: Comprehensive analytics and reporting
- 🤝 **Partner Management**: Manage partner sponsorships and branded alerts

## Tech Stack

- **React 19** - UI framework
- **TypeScript** - Type safety
- **Vite** - Build tool and dev server
- **TailwindCSS** - Utility-first CSS
- **shadcn/ui** - Accessible component library
- **React Router** - Client-side routing
- **TanStack Query** - Server state management
- **Zustand** - Client state management
- **Recharts** - Data visualization
- **MapLibre GL** - Interactive maps

## Getting Started

### Prerequisites

- Node.js 20.11.0 or higher
- npm or yarn
- Backend API running (see `hotspot_api` directory)

### Installation

```bash
# Install dependencies
npm install

# Copy environment variables
cp .env.example .env

# Update .env with your backend API URL
# VITE_API_URL=http://localhost:4000
```

### Development

```bash
# Start development server
npm run dev

# Open browser to http://localhost:5173
```

### Building for Production

```bash
# Build production bundle
npm run build

# Preview production build
npm run preview
```

### Linting

```bash
# Run ESLint
npm run lint
```

## Project Structure

```
hotspot_admin/
├── src/
│   ├── components/       # Reusable UI components
│   │   ├── layout/      # Layout components (Header, Sidebar)
│   │   └── ui/          # shadcn/ui components
│   ├── pages/           # Page components
│   │   ├── DashboardPage.tsx
│   │   ├── IncidentsPage.tsx
│   │   ├── UsersPage.tsx
│   │   ├── ZonesPage.tsx
│   │   ├── AnalyticsPage.tsx
│   │   └── PartnersPage.tsx
│   ├── lib/             # Utilities and helpers
│   │   ├── api.ts       # API client
│   │   └── utils.ts     # Helper functions
│   ├── stores/          # Zustand stores
│   │   └── authStore.ts # Authentication state
│   ├── App.tsx          # Main app component
│   └── main.tsx         # Entry point
├── public/              # Static assets
├── .env.example         # Environment variables template
├── .env.production      # Production environment variables
├── render.yaml          # Render deployment configuration
├── DEPLOYMENT.md        # Deployment guide
└── DEPLOYMENT_CHECKLIST.md  # Deployment checklist
```

## Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `VITE_API_URL` | Backend API URL | `http://localhost:4000` |

## Deployment

See [DEPLOYMENT.md](./DEPLOYMENT.md) for detailed deployment instructions.

### Quick Deploy to Render

1. Push code to GitHub
2. Create new Static Site on Render
3. Connect GitHub repository
4. Configure build settings:
   - Root Directory: `hotspot_admin`
   - Build Command: `npm install && npm run build`
   - Publish Directory: `dist`
5. Add environment variable: `VITE_API_URL`
6. Deploy!

## Admin User Roles

- **Super Admin**: Full access to all features
- **Moderator**: Incident and content moderation
- **Analyst**: Analytics and reporting
- **Partner Manager**: Partner management

## Security

- HTTPS enforced in production
- JWT-based authentication
- Rate limiting on API endpoints
- CORS configured for admin portal origin
- Security headers enabled
- XSS and CSRF protection

## Browser Support

- Chrome (latest)
- Firefox (latest)
- Safari (latest)
- Edge (latest)

## Contributing

1. Create a feature branch
2. Make your changes
3. Run linter: `npm run lint`
4. Build and test: `npm run build`
5. Submit pull request

## License

Proprietary - All rights reserved

## Support

For issues or questions:
- Create an issue in the repository
- Contact the development team
- Check the deployment guide for troubleshooting
