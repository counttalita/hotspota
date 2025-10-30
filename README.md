# Hotspot - Community Safety Reporting App

<div align="center">

**Know what's happening around you before it finds you.**

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![React Native](https://img.shields.io/badge/React%20Native-0.74-61dafb.svg)](https://reactnative.dev/)
[![Node.js](https://img.shields.io/badge/Node.js-20.x-339933.svg)](https://nodejs.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-336791.svg)](https://www.postgresql.org/)

</div>

## 📱 Overview

Hotspot is a real-time, community-driven safety reporting mobile application that helps users stay aware of dangerous areas before they encounter them. Unlike navigation apps, Hotspot focuses purely on **safety awareness** through:

- 🗺️ **Real-time incident mapping** - Hijackings, muggings, and accidents displayed on an interactive map
- 🚨 **Quick one-tap reporting** - Report incidents in seconds with automatic GPS capture
- 🔔 **Geofenced hotspot alerts** - Get notified when entering high-risk zones
- 📊 **Community verification** - Upvote reports to build trust and filter noise
- 📈 **Safety analytics** - Understand when and where risks are highest

### 🎯 Core Concept

Hotspot automatically creates **geofenced danger zones** when incidents cluster in an area. As you drive or travel, you receive real-time alerts:

```
⚠️ Entering HIGH RISK Zone
15 Hijackings reported in this area in the past 7 days. Stay alert.
```

This is **not a navigation app** - it's a safety awareness tool that keeps you informed about your surroundings.

## 🏗️ Project Structure

This monorepo contains three main applications:

```
HotSpota/
├── hotspot_api/          # Backend API (Node.js + Express + PostgreSQL)
├── hotspot_mobile/       # Mobile App (React Native + Expo)
├── hotspot_admin/        # Admin Portal (React + Vite) - Coming soon
└── .kiro/specs/          # Technical specifications
```

### Applications

| Application | Technology | Purpose |
|------------|-----------|---------|
| **Backend API** | Node.js, Express, PostgreSQL+PostGIS | REST API, WebSocket server, geospatial processing |
| **Mobile App** | React Native, Expo, MapLibre | iOS & Android app for end users |
| **Admin Portal** | React, Vite, TailwindCSS | Web dashboard for moderation and analytics |

## 🚀 Quick Start

### Prerequisites

- Node.js 20.x or higher
- PostgreSQL 16 with PostGIS extension
- Redis 7.x
- iOS Simulator (Mac) or Android Studio
- Expo CLI

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/hotspot.git
   cd HotSpota
   ```

2. **Set up the backend**
   ```bash
   cd hotspot_api
   npm install
   cp .env.example .env
   # Edit .env with your database credentials
   npm run db:migrate
   npm run dev
   ```

3. **Set up the mobile app**
   ```bash
   cd hotspot_mobile
   npm install
   cp .env.example .env
   # Edit .env with your API URL
   npx expo start
   ```

4. **Set up the admin portal** (Coming soon)
   ```bash
   cd hotspot_admin
   npm install
   npm run dev
   ```

See individual README files in each directory for detailed setup instructions.

## 🛠️ Tech Stack

### Open-Source Foundation

All core technologies use permissive open-source licenses (MIT, BSD, Apache-2.0):

**Frontend (Mobile)**
- React Native with Expo - Cross-platform mobile development
- MapLibre GL - Open-source mapping engine
- NativeWind - Tailwind CSS for React Native
- Zustand - Lightweight state management
- React Query - Server state and caching

**Backend**
- Node.js + Express.js - REST API server
- Socket.IO - Real-time bidirectional communication
- PostgreSQL + PostGIS - Spatial database
- Redis - Caching and session management
- Auth.js - Authentication

**Admin Portal**
- React + Vite - Fast web development
- TailwindCSS - Utility-first styling
- Recharts - Data visualization
- React Router - Client-side routing

**Infrastructure**
- Render/Railway - Backend hosting
- Firebase Cloud Messaging - Push notifications
- Cloudinary - Image storage and optimization
- GitHub Actions - CI/CD pipeline

### Cost Efficiency

- **Zero licensing fees** - All frameworks use permissive licenses
- **MVP running costs**: ~$30/month (~R600)
- **Scales to 1M users** with near-zero incremental licensing cost
- **Gross margins**: 90%+

## 📋 Features

### MVP (Phase 1)

- [x] Phone number authentication (OTP-based)
- [x] Real-time incident map with color-coded markers
- [x] One-tap incident reporting with photo upload
- [x] Incident feed with filtering
- [x] Push notifications for nearby incidents
- [x] Community verification system
- [x] **Hotspot zone geofencing with entry/exit alerts**
- [x] Heat zone visualization
- [x] Analytics dashboard
- [x] Premium subscriptions (extended radius, Travel Mode)
- [x] Offline support with sync
- [ ] Admin portal for moderation

### Phase 2 (Future)

- [ ] Panic button with emergency contacts
- [ ] Live route risk scoring
- [ ] Nearby emergency services locator
- [ ] Community/neighborhood groups
- [ ] Sponsored alerts (B2B monetization)
- [ ] Enterprise API access

## 💰 Monetization Strategy

### B2C - Freemium Subscription

**Free Tier**
- 2km alert radius
- Basic incident feed
- Standard notifications

**Premium (R49-R99/month)**
- 10km alert radius
- Travel Mode (pre-trip safety summaries)
- Background notifications
- Advanced analytics
- 500m advance hotspot warnings

### B2B - Sponsored Alerts

Partner with safety-focused brands:
- Insurance companies (Outsurance, Discovery)
- Security firms (ADT, Tracker, Fidelity)
- Roadside assistance (AA, Netstar)

**Example**: "Incident verified by Tracker Secure" badge

### B2B - Enterprise Licensing

White-label dashboards for:
- Courier fleets (Takealot, Checkers Sixty60)
- Ride-hailing operators (Uber, Bolt)
- Corporate fleet management
- Tourism operators

**Pricing**: R2,000-R10,000/month per organization

## 🎯 Target Market

### Primary Users
- Frequent travelers and commuters
- Delivery and logistics drivers
- Ride-hailing operators (Uber/Bolt)
- Tourists visiting unfamiliar areas

### Geographic Focus
- **Phase 1**: South Africa (Gauteng, Western Cape)
- **Phase 2**: Expand to high-risk travel regions globally

### Market Opportunity
- 10M+ daily commuters in South Africa
- 800K+ gig economy drivers
- $10B+ global personal safety tech market

## 📖 Documentation

- [Requirements Specification](./.kiro/specs/hotspot-app/requirements.md)
- [Design Document](./.kiro/specs/hotspot-app/design.md)
- [Implementation Tasks](./.kiro/specs/hotspot-app/tasks.md)
- [Backend API README](./hotspot_api/README.md)
- [Mobile App README](./hotspot_mobile/README.md)
- [Admin Portal README](./hotspot_admin/README.md) (Coming soon)

## 🧪 Testing

```bash
# Backend tests
cd hotspot_api
npm test

# Mobile app tests
cd hotspot_mobile
npm test

# E2E tests
npm run test:e2e
```

## 🚢 Deployment

### Backend
- Production: Render/Railway
- Database: PostgreSQL with PostGIS on Render
- Redis: Upstash or Render Redis

### Mobile App
- iOS: App Store via Expo EAS Build
- Android: Google Play via Expo EAS Build

### Admin Portal
- Vercel or Netlify for static hosting

See deployment guides in individual README files.

## 🤝 Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- MapLibre for open-source mapping
- PostGIS for geospatial capabilities
- The React Native and Expo communities
- All contributors and early adopters

## 📞 Contact

- **Website**: https://hotspot.app (Coming soon)
- **Email**: hotspot@tosh.co.za
- **Twitter**: [@HotspotApp](https://twitter.com/HotspotApp)

---

<div align="center">

**Stay alert. Travel smart.**

Made with ❤️ in South Africa

</div>
