# Admin Portal Deployment Checklist

Use this checklist to ensure a smooth deployment to production.

## Pre-Deployment

### Code Quality
- [ ] All TypeScript compilation errors resolved (`npm run build` succeeds)
- [ ] ESLint warnings addressed (`npm run lint`)
- [ ] No console.log statements in production code
- [ ] All environment variables documented in `.env.example`
- [ ] Git repository is clean (no uncommitted changes)

### Testing
- [ ] All admin features tested locally
- [ ] Login/logout flow works correctly
- [ ] API integration tested with production-like backend
- [ ] Responsive design tested on mobile, tablet, desktop
- [ ] Browser compatibility tested (Chrome, Firefox, Safari, Edge)
- [ ] Network error handling tested (offline mode)

### Security
- [ ] No sensitive data (API keys, passwords) in code
- [ ] HTTPS enforced for all API calls
- [ ] CORS configured correctly on backend
- [ ] Rate limiting implemented on backend admin endpoints
- [ ] Admin authentication working properly
- [ ] Session timeout configured appropriately

### Performance
- [ ] Production build size < 500KB gzipped
- [ ] Images optimized and compressed
- [ ] Lazy loading implemented for routes
- [ ] Bundle analyzed for unnecessary dependencies

## Backend Configuration

### CORS Setup
- [ ] Admin portal origin added to CORS whitelist
- [ ] Render URL added: `https://hotspot-admin.onrender.com`
- [ ] Custom domain added (if applicable): `https://admin.hotspot.app`
- [ ] Development origins removed from production config
- [ ] Backend redeployed with updated CORS config

### Rate Limiting
- [ ] Rate limiter plug created and tested
- [ ] Admin pipeline includes rate limiting
- [ ] Rate limit headers returned in responses
- [ ] Rate limit exceeded error handled gracefully

### Admin Users
- [ ] Admin user migration run
- [ ] Seed script executed to create initial admin accounts
- [ ] Default passwords changed for all admin accounts
- [ ] Admin roles assigned correctly
- [ ] Test login with each admin account

## Render Deployment

### Static Site Configuration
- [ ] Render account created/logged in
- [ ] New static site created
- [ ] GitHub repository connected
- [ ] Root directory set to `hotspot_admin`
- [ ] Build command: `npm install && npm run build`
- [ ] Publish directory: `dist`
- [ ] Auto-deploy enabled

### Environment Variables
- [ ] `VITE_API_URL` set to production backend URL
- [ ] `NODE_VERSION` set to `20.11.0` (or latest LTS)
- [ ] All required environment variables configured

### Build Settings
- [ ] First build completed successfully
- [ ] Build logs reviewed for errors/warnings
- [ ] Build time < 5 minutes
- [ ] Deploy preview URL accessible

### SSL/HTTPS
- [ ] SSL certificate automatically provisioned
- [ ] HTTPS enforced (HTTP redirects to HTTPS)
- [ ] SSL certificate valid and not expired
- [ ] Mixed content warnings resolved

### Custom Domain (Optional)
- [ ] Custom domain added in Render dashboard
- [ ] DNS CNAME record created
- [ ] DNS propagation complete (check with `dig` or `nslookup`)
- [ ] SSL certificate issued for custom domain
- [ ] Custom domain accessible via HTTPS

## Post-Deployment Testing

### Functionality Testing
- [ ] Admin portal loads without errors
- [ ] Login page accessible
- [ ] Login with valid credentials succeeds
- [ ] Dashboard displays correct data
- [ ] All navigation links work
- [ ] Real-time features work (WebSocket connection)
- [ ] API calls succeed (check Network tab)
- [ ] Logout functionality works

### Feature Testing
- [ ] **Dashboard**: Stats cards, activity feed, charts
- [ ] **Incidents**: List, search, filter, moderate, bulk actions
- [ ] **Users**: List, search, view details, suspend/ban, premium management
- [ ] **Zones**: List, create, edit, delete, view incidents
- [ ] **Analytics**: Trends, heatmap, peak hours, export
- [ ] **Partners**: List, add, edit, delete, view stats

### Error Handling
- [ ] Invalid login shows error message
- [ ] Network errors handled gracefully
- [ ] 404 page displays for invalid routes
- [ ] API errors show user-friendly messages
- [ ] Rate limit errors handled properly

### Performance
- [ ] Page load time < 3 seconds
- [ ] Time to Interactive < 5 seconds
- [ ] Lighthouse score > 90 (Performance)
- [ ] No console errors in production
- [ ] Images load quickly
- [ ] Smooth scrolling and interactions

### Security
- [ ] Unauthenticated users redirected to login
- [ ] Protected routes require authentication
- [ ] Session persists across page refreshes
- [ ] Session expires after inactivity
- [ ] HTTPS enforced (no mixed content)
- [ ] Security headers present (check DevTools)

### Browser Compatibility
- [ ] Chrome (latest)
- [ ] Firefox (latest)
- [ ] Safari (latest)
- [ ] Edge (latest)
- [ ] Mobile Safari (iOS)
- [ ] Chrome Mobile (Android)

### Responsive Design
- [ ] Mobile (320px - 767px)
- [ ] Tablet (768px - 1023px)
- [ ] Desktop (1024px+)
- [ ] Large desktop (1920px+)

## Monitoring Setup

### Render Monitoring
- [ ] Build notifications enabled
- [ ] Deploy notifications configured
- [ ] Error alerts set up
- [ ] Bandwidth usage monitored

### Application Monitoring
- [ ] Error tracking configured (Sentry, etc.)
- [ ] Analytics configured (Google Analytics, PostHog, etc.)
- [ ] Performance monitoring enabled
- [ ] Uptime monitoring configured (UptimeRobot, etc.)

### Logging
- [ ] Backend API logs accessible
- [ ] Frontend errors logged to backend
- [ ] Admin actions logged to audit table
- [ ] Security events logged

## Documentation

### Internal Documentation
- [ ] Deployment guide updated
- [ ] Environment variables documented
- [ ] Admin user roles documented
- [ ] Troubleshooting guide created
- [ ] Rollback procedure documented

### Team Onboarding
- [ ] Admin credentials shared securely
- [ ] Access instructions provided
- [ ] Feature walkthrough completed
- [ ] Support contacts documented

## Maintenance Plan

### Regular Tasks
- [ ] Weekly: Review error logs
- [ ] Weekly: Check performance metrics
- [ ] Monthly: Update dependencies
- [ ] Monthly: Review security advisories
- [ ] Quarterly: Rotate admin passwords
- [ ] Quarterly: Review and update documentation

### Backup Plan
- [ ] Database backup schedule confirmed
- [ ] Backup restoration tested
- [ ] Disaster recovery plan documented

## Sign-Off

### Deployment Team
- [ ] Developer sign-off: _______________
- [ ] QA sign-off: _______________
- [ ] Product owner sign-off: _______________

### Deployment Details
- Deployment date: _______________
- Deployed by: _______________
- Production URL: _______________
- Backend API URL: _______________
- Git commit hash: _______________

### Post-Deployment Notes
```
Add any notes about the deployment here:
- Issues encountered
- Workarounds applied
- Follow-up tasks
```

## Rollback Procedure

If critical issues are discovered:

1. **Immediate Actions**
   - [ ] Notify team of issues
   - [ ] Document the problem
   - [ ] Assess severity and impact

2. **Rollback Steps**
   - [ ] Go to Render dashboard
   - [ ] Navigate to "Deploys" tab
   - [ ] Find last working deployment
   - [ ] Click "Redeploy"
   - [ ] Verify rollback successful

3. **Post-Rollback**
   - [ ] Notify team of rollback
   - [ ] Create incident report
   - [ ] Plan fix and redeployment
   - [ ] Update this checklist with lessons learned

## Success Criteria

Deployment is considered successful when:
- [ ] All checklist items completed
- [ ] No critical errors in production
- [ ] All admin features working as expected
- [ ] Performance metrics meet targets
- [ ] Security requirements satisfied
- [ ] Team trained and comfortable with system
- [ ] Monitoring and alerts configured
- [ ] Documentation complete and accessible

---

**Deployment Status**: ⬜ Not Started | 🟡 In Progress | ✅ Complete | ❌ Failed

**Last Updated**: _______________
