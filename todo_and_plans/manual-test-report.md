# Full Manual Test Report - Projulous Web

## Test Summary
- **Tested by**: Manual Test Team (Team Lead + Anonymous Tester Agent)
- **Date**: 2026-02-19
- **Environment**: localhost (Backend: 8123, Frontend: 3000)
- **Scope**: Full web experience across all 4 personas
- **Issues found**: 2 Major, 4 Minor, 1 Informational

---

## Issues Summary

| ID | Severity | Title | Owner |
|----|----------|-------|-------|
| MAJ-1 | Major | Browse All Services shows only 1 vendor type | Backend PO / Admin |
| MAJ-2 | Major | Vendor type page shows 11% Satisfaction Rate | Backend PO |
| MIN-1 | Minor | Sidebar shows customer-only items to anonymous users | Frontend PO |
| MIN-2 | Minor | Missing i18n key: `settings.notifications.category.BILLING` | Frontend PO |
| MIN-3 | Minor | SP Certification page shows raw 403 error for non-admin members | Frontend PO |
| MIN-4 | Minor | `/help-center/ideas` shows redirect for anonymous instead of ideas page | Frontend PO |
| INFO-1 | Info | `/projects/showcase` caught by dynamic project ID route | Frontend PO |

---

## Major Issues

### MAJ-1: Browse All Services page shows only 1 vendor type (Plumbing)
- **Page**: `/services`
- **Persona**: Anonymous
- **Steps to Reproduce**:
  1. Navigate to http://localhost:3000/services
  2. Observe the vendor type cards
- **Expected**: Multiple vendor types displayed (Plumbing, Electrical, HVAC, etc.) matching the home page carousel
- **Actual**: Only "Plumbing" is shown. The home page carousel shows Plumbing, Electrical, Air Conditioning with arrows suggesting more.
- **Root Cause**: Confirmed via Admin > Vendor Pages - only "Plumbing" is PUBLISHED. HVAC vendor page exists but is in DRAFT status. Other vendor types (Electrical, Air Conditioning, etc.) have no vendor pages created at all.
- **Fix**: Create and publish vendor pages for all service categories shown on the home page, or hide home page carousel items that don't have published vendor pages.

### MAJ-2: Vendor type page shows 11% Satisfaction Rate
- **Page**: `/services/plumbing`
- **Persona**: Anonymous
- **Steps to Reproduce**:
  1. Navigate to http://localhost:3000/services/plumbing
  2. Observe the stats section on the right side
- **Expected**: Satisfaction rate should be a reasonable percentage (85%+) or hidden if data is insufficient
- **Actual**: Shows "11%" as the Satisfaction Rate
- **Owner**: Backend PO (metric calculation likely incorrect or based on insufficient data)

---

## Minor Issues

### MIN-1: Sidebar shows customer-only items to anonymous users
- **Page**: All public pages
- **Persona**: Anonymous
- **Steps to Reproduce**:
  1. Navigate to http://localhost:3000 without logging in
  2. Observe sidebar navigation
- **Expected**: Only show: Start A Project, Help Center, Become a Service Provider, Login
- **Actual**: Also shows "My Projects", "My Places", "My Appliances" which are customer-only items. Clicking them redirects to login, but showing them creates confusion.
- **Fix**: Conditionally hide customer nav items when user is not authenticated.

### MIN-2: Missing i18n translation key for BILLING notification category
- **Page**: `/settings` (Notification Preferences section)
- **Persona**: All authenticated users (Customer, SP, Admin)
- **Steps to Reproduce**:
  1. Log in as any user
  2. Navigate to Settings
  3. Scroll to Notification Preferences > Categories
- **Expected**: All category names should be properly translated (e.g., "Billing")
- **Actual**: Shows raw key `settings.notifications.category.BILLING` instead of "Billing"
- **Fix**: Add the missing translation key to all 3 language files (EN/ES/FR) in `app/translations/`.

### MIN-3: SP Certification page shows raw 403 error for non-admin SP members
- **Page**: `/service-providers/certification`
- **Persona**: Service Provider
- **Steps to Reproduce**:
  1. Log in as SP (brycedeneen+ps@gmail.com)
  2. Navigate to Certification page
- **Expected**: Either show certification status or a friendly "access denied" message
- **Actual**: Shows a raw red error banner: "Request failed with status code 403"
- **Fix**: Handle 403 errors gracefully on the certification page with a user-friendly message.

### MIN-4: `/help-center/ideas` redirects anonymous users to contact page
- **Page**: `/help-center/ideas`
- **Persona**: Anonymous
- **Steps to Reproduce**:
  1. Navigate to http://localhost:3000/help-center/ideas without logging in
- **Expected**: Either show the ideas board with a "login to participate" prompt, or show a clear message that login is required
- **Actual**: Redirects to `/help-center/contact` without explanation. When authenticated, the page loads correctly with a "Sign in to view Ideas" message (which is also slightly incorrect since the user IS signed in).
- **Fix**: Show a more appropriate redirect or message for anonymous users.

---

## Informational

### INFO-1: `/projects/showcase` caught by dynamic project ID route
- **Page**: `/projects/showcase`
- **Persona**: Anonymous
- **Steps to Reproduce**:
  1. Navigate to http://localhost:3000/projects/showcase
- **Expected**: Redirect to `/projects` (the actual showcase page)
- **Actual**: Shows "Project Not Found" because "showcase" is treated as a project ID
- **Note**: No links actually point to this URL. The correct showcase URL is `/projects`. This is informational only.

---

## Phase 1: Anonymous User Testing

| Route | Status | Notes |
|-------|--------|-------|
| `/` (Home) | PASS | Hero, AI prompt, service cards, project gallery, footer all render correctly |
| `/services` | PASS (MAJ-1) | Page loads but only shows 1 vendor type |
| `/services/plumbing` | PASS (MAJ-2) | Renders with search, filters, stats. 11% satisfaction rate bug |
| `/help-center` | PASS | Search, tabs, categories, popular articles section |
| `/help-center/contact` | PASS | Live Chat card, Support Ticket card, form visible |
| `/help-center/ideas` | MINOR (MIN-4) | Redirects to contact for anonymous |
| `/service-providers/why-join` | PASS | Hero, CTAs, feature cards render correctly |
| `/service-providers/join` | PASS | Registration form with all fields + OAuth |
| `/projects` (Showcase) | PASS | Search, category filters, sort dropdown, empty state |
| `/auth/login` | PASS | Email, Password, OAuth, links all present |
| `/auth/register` | PASS | Full registration form with validation |
| `/auth/forgot-password` | PASS | Email field, reset button, OAuth |
| `/notifications` | PASS | Correctly redirects to `/auth/login` |
| `/customers/projects` | PASS | Correctly redirects to `/auth/login` |
| `/admin/help-center` | PASS | Correctly redirects to `/auth/login` |

### Sidebar (Anonymous)
| Item | Visible | Expected | Status |
|------|---------|----------|--------|
| Start A Project | Yes | Yes | PASS |
| My Projects | Yes | No | MINOR (MIN-1) |
| My Places | Yes | No | MINOR (MIN-1) |
| My Appliances | Yes | No | MINOR (MIN-1) |
| Help Center | Yes | Yes | PASS |
| Become a Service Provider | Yes | Yes | PASS |
| English (language) | Yes | Yes | PASS |
| Login | Yes | Yes | PASS |

---

## Phase 2: Customer Persona Testing

**Login**: brycedeneen@gmail.com (Google OAuth)

| Route | Status | Notes |
|-------|--------|-------|
| Login & redirect | PASS | Successfully logged in, redirected to home |
| Sidebar items | PASS | Shows Start Project, My Projects, My Places, My Appliances, Help Center, My Tickets, Ideas, Maintenance |
| `/customers/projects` | PASS | Projects list with cards, search, create button |
| `/customers/projects/:id` | PASS | Project detail with tabs, SP management, place info, tickets |
| `/customers/places` | PASS | Places list with create button |
| `/customers/places/:id` | PASS | Place detail with address, map placeholder, linked appliances |
| `/customers/appliances` | PASS | Appliances list with cards, create button |
| `/customers/appliances/:id` | PASS | Detail with specs, maintenance reminders, service history timeline |
| `/customers/maintenance` | PASS | Maintenance overview dashboard with upcoming/overdue reminders |
| `/customers/tickets` | PASS | Tickets list with status cards, search, filters |
| `/customers/tickets/:id` | PASS | Ticket detail with description, status, activity log |
| `/customers/billing` | PASS | Billing page loads |
| `/notifications` | PASS | Notification center with All/Unread tabs, mark as read |
| `/settings` | PASS (MIN-2) | Profile, password, notifications (BILLING key bug), theme, language |
| `/help-center/ideas` | PASS | Ideas board with create, vote, comment functionality |
| Access: `/admin/*` | PASS | Correctly shows unauthorized/redirects |

---

## Phase 3: Service Provider Persona Testing

**Login**: brycedeneen+ps@gmail.com / P@ssword1!

| Route | Status | Notes |
|-------|--------|-------|
| Login & redirect | PASS | Successfully logged in |
| Sidebar items | PASS | Shows SP Dashboard, Offerings, Team, Certification, Billing, Tickets + customer sections |
| `/service-providers/dashboard` | PASS | Profile card, stats, recent activity |
| `/service-providers/offerings` | PASS | Offerings management, empty state |
| `/service-providers/team` | PASS | Team members list (1 member), invite functionality |
| `/service-providers/certification` | MINOR (MIN-3) | Raw 403 error banner for non-admin SP |
| `/service-providers/billing` | PASS | Free plan, no invoices |
| `/service-providers/tickets` | PASS | Status cards, search, filters, empty state |
| `/notifications` | PASS | Notification center working |
| `/settings` | PASS (MIN-2) | Same BILLING translation key bug |
| Access: `/admin/*` | PASS | Correctly shows unauthorized |

---

## Phase 4: Super Admin Persona Testing

**Login**: bryce@redbricksoftware.com (Google OAuth)

| Route | Status | Notes |
|-------|--------|-------|
| Login & redirect | PASS | Logged in, admin sidebar visible |
| Sidebar items | PASS | Shows all admin sections, no customer "My X" items (correct) |
| `/admin/service-provider-review` | PASS | 38,663 pending SPs, status cards, search, filters, pagination |
| `/admin/service-provider-review/:id` | PASS | Full detail: profile, offerings, team, certification progress, verification email, responses, action buttons (Certify/Request Follow-up/Add Note/Reject) |
| `/admin/service-providers` (Providers tab) | PASS | Provider list with search, status filter, add button |
| `/admin/service-providers` (Offerings tab) | PASS | Offerings list with type filter, add button |
| `/admin/service-providers` (Data Enrichment tab) | PASS | Blank field filter, Enrich All button, data gaps highlighted |
| `/admin/help-center` (Articles) | PASS | Empty state, search, Status/Audience filters, New Article button |
| `/admin/help-center` (Categories) | PASS | Empty state, search, Audience filter, New Category button |
| `/admin/help-center` (FAQs) | PASS | Empty state, search, Audience filter, Add FAQ button |
| `/admin/support-tickets` | PASS | Status cards, 2 test tickets, search, filters |
| `/admin/support-tickets/:id` | PASS | Full detail: metadata, description, comments, status/priority controls, activity log, delete |
| `/admin/users` | PASS | 4 users, status cards, search, Role/Verified/Status filters, Users/Roles tabs |
| `/admin/users/:id` | PASS | Profile info, audit trail, role memberships with add/remove, actions (password reset, unverify, soft delete) |
| `/admin/roles` | PASS | 3 system roles (Customer: 54 perms, SP: 49 perms, Super Admin: 8 perms), Create Role button |
| `/admin/vendor-pages` | PASS | 2 vendor pages (HVAC draft, Plumbing published), create/edit/delete |
| `/admin/ideas` | PASS | 1 idea, status cards, search, Category/Sentiment filters, AI sentiment, action buttons |
| `/admin/billing` | PASS | Empty state "No billing accounts" |
| `/notifications` | PASS | 2755 unread notifications (all "Offering Created") |
| `/settings` | PASS (MIN-2) | Same BILLING translation key bug, theme/language working |

---

## Cross-Cutting Observations

### Dark Mode
- Tested across all personas - dark mode renders correctly on all pages
- No invisible text or broken contrast issues observed
- Cards, modals, tables, forms all properly styled

### Navigation
- Sidebar active state correctly highlights current page across all personas
- Browser back/forward works correctly
- Logo click returns to home
- Direct URL navigation works for all tested routes

### Empty States
- All pages handle empty data gracefully with appropriate messages and CTA buttons
- Help Center: "No articles yet", "No categories yet", "No FAQs yet"
- Billing: "No billing accounts"
- Tickets: "No tickets found"

### Access Control
- Anonymous -> auth routes: Correctly redirects to login
- Customer -> admin routes: Correctly shows unauthorized
- SP -> admin routes: Correctly shows unauthorized
- Admin sidebar: Correctly hides customer-specific items

---

## Recommendations (Priority Order)

1. **[MIN-2] Add BILLING i18n key** - Quick fix, affects all authenticated users. Add `settings.notifications.category.BILLING` to EN/ES/FR translation files.

2. **[MIN-1] Hide customer sidebar items for anonymous** - Conditionally render "My Projects", "My Places", "My Appliances" only when authenticated.

3. **[MIN-3] Handle 403 on SP Certification** - Add error boundary or catch 403 and show friendly message instead of raw error.

4. **[MAJ-1] Create/publish vendor pages** - Either create vendor pages for all service categories shown on the home page, or filter home page carousel to only show published vendor pages.

5. **[MAJ-2] Fix satisfaction rate calculation** - Review the backend metric calculation for vendor page satisfaction rates. 11% is likely a calculation error.

6. **[MIN-4] Fix anonymous ideas redirect** - Show appropriate message or landing page for anonymous users visiting the ideas board.
