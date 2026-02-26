# Redbrick Software Mobile - Admin App Plan

## Overview

Clone `projulous-mobile` into a new `redbrick-software-mobile` Expo app that implements **admin-only** features from `projulous-web`. This app is exclusively for **SUPER_ADMIN** users to manage the Projulous platform on-the-go: support tickets, ideas, SP certification, AI/audit logs, user management, etc.

**No customer or service provider features.** No projects, appliances, places, AI chat, maintenance, or anonymous browsing.

---

## Phase 0: Project Scaffolding & Clone

### 0.1 Clone & Rebrand
- [ ] Copy `projulous-mobile/` to `redbrick-software-mobile/`
- [ ] Update `app.json`:
  - Name: "Redbrick Software"
  - Slug: `redbrick-software-mobile`
  - iOS bundle ID: `com.redbricksoftware.admin`
  - Android package: `com.redbricksoftware.admin`
  - Deep link scheme: `redbrickadmin://`
  - New EAS project ID (run `eas init`)
  - Update splash screen / icon with Redbrick branding
- [ ] Update `eas.json` with new build profiles
- [ ] Update `package.json` name, description
- [ ] New app icon & splash screen using Redbrick logo
  - Source logo: `/Users/brycedeneen/Documents/dev/ta/ta-mobile-backup/src/assets/img/redbricksoftwarediagonal.png`
  - Generate app icon from logo (crimson red on white)
  - Splash screen: white background with Redbrick Software logo centered

### 0.2 Strip Customer/SP Features
Remove these files/directories entirely:
- [ ] `app/(tabs)/projects.tsx` - customer projects
- [ ] `app/(tabs)/pj.tsx` - AI chat tab
- [ ] `app/(tabs)/appliances.tsx` - customer appliances
- [ ] `app/(tabs)/schedule.tsx` - SP schedule
- [ ] `app/project/` directory (all project screens)
- [ ] `app/appliance/` directory (all appliance screens)
- [ ] `app/settings/places.tsx`, `place-form.tsx`, `place-detail.tsx` - customer places
- [ ] `components/chat/` directory (all chat components)
- [ ] `components/projects/` directory
- [ ] `components/appliance/` directory
- [ ] `dataAccess/chat/`, `dataAccess/conversation/`
- [ ] `dataAccess/customer/` (all customer data access)
- [ ] `dataAccess/googlePlaces/`
- [ ] `dataAccess/helpCenter/` (customer-facing; will rebuild for admin)
- [ ] `hooks/use-pj-chat.ts`
- [ ] `hooks/use-list-sort.ts` (evaluate if admin screens need it - likely keep)
- [ ] `contexts/user-type.context.tsx` (no user type switching - always admin)
- [ ] `utils/appliance-icons.ts`, `utils/imageCompression.ts`
- [ ] `constants/tab-config.ts` (rewrite for admin tabs)
- [ ] Remove all customer/SP i18n namespaces: `projects`, `appliances`, `places`, `chat`, `maintenance`

### 0.3 Auth Changes
- [ ] **OAuth-only login** (Google/Apple):
  - Remove email/password login form entirely
  - Login screen shows only "Sign in with Google" and "Sign in with Apple" buttons
  - After OAuth, decode JWT and check for `SUPER_ADMIN` permission
  - If user is not SUPER_ADMIN, show error "Access restricted to administrators" and clear tokens
  - Remove registration screens (`register.tsx`, `confirm-registration.tsx`)
  - Remove `forgot-password.tsx`, `confirm-reset.tsx` (no password to reset)
  - Remove `accept-policies.tsx` (admins don't need policy acceptance flow)
  - Keep OAuth deep link scheme updated to `redbrickadmin://oauth-callback`
- [ ] Simplify `AuthContext`:
  - Remove `customerId`, `serviceProviderId` from user model
  - Add `permissions: string[]` to user model for permission-gated UI
  - Remove `UserTypeContext` entirely
- [ ] Simplify `auth.da.ts`:
  - Remove `login()`, `register()`, `forgotPassword()`, `confirmReset()`, `confirmRegistration()`
  - Keep `handleOAuthLogin()`, `exchangeCode()`, `logOut()`, `refreshToken()`

### 0.4 Keep & Reuse
- [ ] `dataAccess/apiAccessV2.da.ts` (REST client) - keep as-is
- [ ] `dataAccess/graphqlAPIAccessV2.da.ts` (GraphQL client) - keep as-is
- [ ] `dataAccess/tokenRefresh.service.ts` - keep as-is
- [ ] `dataAccess/storage.service.ts` - keep as-is
- [ ] `dataAccess/auth/auth.da.ts` - keep, simplify (remove register, password login, keep OAuth)
- [ ] `contexts/auth.context.tsx` - keep, simplify
- [ ] `contexts/theme-preference.context.tsx` - keep as-is
- [ ] `contexts/notification.context.tsx` - keep as-is
- [ ] `hooks/use-auth.ts`, `use-color-scheme.ts`, `use-theme-color.ts`, `use-debounce.ts` - keep
- [ ] `components/ui/` - keep all form & common UI components
- [ ] `components/navigation/custom-tab-bar.tsx` - keep, modify for admin tabs
- [ ] `i18n/` setup - keep, add admin namespaces
- [ ] `config/api.config.ts` - keep as-is
- [ ] `constants/theme.ts` - keep, update brand colors if needed
- [ ] `utils/date/`, `utils/format.util.ts`, `utils/string/` - keep
- [ ] `utils/pushNotifications.ts` - keep
- [ ] `utils/confirm-delete.ts` - keep

---

## Phase 1: Core Navigation & Dashboard

### 1.1 Admin Tab Structure (DECIDED: 4 Tabs + More Menu)

```
Bottom Tabs:
1. Dashboard        - Overview stats, recent activity, quick actions
2. Support Tickets  - Support ticket management (daily use)
3. Activity         - Audit Logs + AI Logs (segmented control)
4. Settings         - Theme, language, notifications, logout

"More" sections (accessible from Dashboard quick actions or header menu):
- Users & Roles
- Service Providers
- SP Certification Review
- SP Claims
- Ideas/Feedback
- Help Center
- Vendor Pages
- Billing
```

### 1.2 Dashboard Screen (`app/(tabs)/index.tsx`)
- [ ] Stat cards row: Total Users, Open Tickets, Pending SP Certifications, Ideas Under Review
- [ ] Recent activity feed (last 10 audit log entries)
- [ ] Quick actions: "Review Ticket", "Certify SP", "View AI Logs"
- [ ] Unread admin notifications count
- [ ] System health indicators (optional v2)

### 1.3 Admin Navigation Routes
```
app/
├── (auth)/
│   ├── _layout.tsx
│   └── login.tsx              # Admin-only login
├── (tabs)/
│   ├── _layout.tsx            # Admin tab bar
│   ├── index.tsx              # Dashboard
│   ├── support.tsx            # Support tickets list
│   ├── activity.tsx           # Audit + AI logs
│   └── settings.tsx           # Admin settings
├── more/                      # "More" menu items
│   ├── _layout.tsx
│   ├── index.tsx              # Grid/list of all admin sections
│   ├── users.tsx              # User management
│   ├── roles.tsx              # Role management
│   ├── service-providers.tsx  # SP management
│   ├── sp-review.tsx          # SP certification
│   ├── sp-claims.tsx          # SP claims
│   ├── ideas.tsx              # Feedback/ideas
│   ├── help-center.tsx        # Help center admin
│   ├── vendor-pages.tsx       # Vendor page admin
│   └── billing.tsx            # Billing overview
├── support-ticket/
│   ├── _layout.tsx
│   └── [ticketId].tsx         # Ticket detail + comments
├── user/
│   ├── _layout.tsx
│   └── [userId].tsx           # User detail
├── role/
│   ├── _layout.tsx
│   └── [roleId].tsx           # Role detail + permissions
├── service-provider/
│   ├── _layout.tsx
│   ├── [serviceProviderId].tsx  # SP detail
│   └── review/
│       └── [serviceProviderId].tsx  # SP certification review
├── idea/
│   ├── _layout.tsx
│   └── [feedbackSubmissionId].tsx  # Idea detail
├── audit-log/
│   ├── _layout.tsx
│   └── detail.tsx             # Expanded log view + AI analysis
├── help-center/
│   ├── _layout.tsx
│   ├── article-form.tsx       # Create/edit article
│   ├── category-form.tsx      # Create/edit category
│   └── faq-form.tsx           # Create/edit FAQ
├── vendor-page/
│   ├── _layout.tsx
│   └── form.tsx               # Create/edit vendor page
├── settings/
│   ├── _layout.tsx
│   └── notifications.tsx      # Notification preferences
└── notifications/
    ├── _layout.tsx
    └── index.tsx              # Admin notifications
```

---

## Phase 2: Data Access Layer

### 2.1 New Admin Data Access Classes
Port from `projulous-web/app/dataAccess/` to mobile format (axios + secure store auth):

- [ ] `dataAccess/admin/adminUser.da.ts`
  - `getUsers(filters)` - paginated user list
  - `getUserById(userId)` - user detail
  - `sendPasswordReset(userId)` - trigger reset email
  - `softDeleteUser(userId)` - deactivate
  - `restoreUser(userId)` - reactivate
- [ ] `dataAccess/admin/adminRole.da.ts`
  - `getRoles()` - all roles
  - `getRoleById(roleId)` - role detail with permissions
  - `getRoleMembers(roleId)` - users in role
  - `getRolePermissions(roleId)` - permissions assigned
  - `createRole(dto)`, `updateRole(roleId, dto)`, `deleteRole(roleId)`
  - `bulkSetRolePermissions(roleId, permissionIds)`
  - `getPermissions()` - all available permissions
- [ ] `dataAccess/admin/auditLog.da.ts`
  - `getAuditLogs(filters)` - paginated, filterable
  - `analyzeAuditLogs(logIds, context)` - AI analysis
- [ ] `dataAccess/admin/aiInteractionLog.da.ts`
  - `getAILogs(filters)` - paginated, filterable
- [ ] `dataAccess/admin/supportTicket.da.ts`
  - `getTickets(filters)` - paginated list
  - `getTicketById(ticketId)` - detail with comments
  - `updateTicketStatus(ticketId, status)`
  - `addComment(ticketId, body, isInternal)`
- [ ] `dataAccess/admin/feedback.da.ts`
  - `getFeedback(filters)` - paginated list
  - `getFeedbackById(id)` - detail
  - `updateFeedbackStatus(id, status)`
  - `mergeIdeas(sourceId, targetId)`
  - `deleteFeedback(id)`
- [ ] `dataAccess/admin/serviceProvider.da.ts`
  - `getServiceProviders(filters)` - paginated list
  - `getServiceProviderById(id)` - detail
  - `getOfferings(filters)` - paginated offerings
  - `updateCertificationStatus(id, status)`
  - `enrichProvider(id)` - trigger AI enrichment
  - `bulkEnrich(ids)` - bulk enrichment
- [ ] `dataAccess/admin/spClaim.da.ts`
  - `getPendingClaims()` - claims needing review
  - `approveClaim(claimId)` - approve
  - `rejectClaim(claimId, notes)` - reject with reason
- [ ] `dataAccess/admin/helpCenter.da.ts`
  - `getArticles(filters)`, `getArticleById(id)`
  - `createArticle(dto)`, `updateArticle(id, dto)`, `deleteArticle(id)`
  - `getCategories()`, `createCategory(dto)`, `updateCategory(id, dto)`, `deleteCategory(id)`
  - `getFaqs(filters)`, `createFaq(dto)`, `updateFaq(id, dto)`, `deleteFaq(id)`
- [ ] `dataAccess/admin/vendorPage.da.ts`
  - `getVendorPages(filters)`, `getVendorPageById(id)`
  - `createVendorPage(dto)`, `updateVendorPage(id, dto)`, `deleteVendorPage(id)`
  - `recalculateRankings()`
- [ ] `dataAccess/admin/billing.da.ts`
  - `getBillingAccounts(filters)` - paginated list

---

## Phase 3: Feature Implementation (Priority Order)

### Tier 1 - High Priority (Daily Admin Use)

#### 3.1 Support Tickets (`support.tsx` + detail)
- [ ] List with status filter chips (OPEN, IN_PROGRESS, RESOLVED, CLOSED)
- [ ] Category & priority filter
- [ ] Search by subject
- [ ] Stat cards (count per status)
- [ ] Pull-to-refresh
- [ ] Tap → detail screen:
  - Ticket info (subject, description, category, priority, status)
  - User info (who submitted)
  - Conversation link (if applicable)
  - Comment thread (internal + public)
  - Add comment (with internal toggle)
  - Change status action

#### 3.2 Dashboard (`index.tsx`)
- [ ] Stat cards: Open Tickets, Pending SPs, New Ideas, Active Users
- [ ] Recent audit log entries (last 10)
- [ ] Quick action buttons
- [ ] Pull-to-refresh

#### 3.3 Admin Notifications
- [ ] Reuse existing notification system
- [ ] Filter for admin-relevant notification types only

### Tier 2 - Important (Weekly Admin Use)

#### 3.4 Ideas/Feedback Management (`more/ideas.tsx` + detail)
- [ ] List with status filters (NEW, UNDER_REVIEW, PLANNED, etc.)
- [ ] Category & sentiment filter
- [ ] Search by title
- [ ] Stat cards per status
- [ ] AI priority score display
- [ ] Tap → detail screen:
  - Full idea details
  - AI analysis (sentiment, tags, scores)
  - Vote counts
  - Status update action
  - Admin notes
  - Delete action
- [ ] Merge ideas (select two → merge modal)

#### 3.5 SP Certification Review (`more/sp-review.tsx` + detail)
- [ ] List of SPs pending certification
- [ ] Filter by certification status
- [ ] Tap → review screen:
  - SP info (name, email, phone, website, rating)
  - Offerings list
  - Certification timeline/history
  - Verification responses
  - Action buttons: Approve / Request Info / Deny
  - Admin notes

#### 3.6 User Management (`more/users.tsx` + detail)
- [ ] User list with role filter (SUPER_ADMIN, SP, CUSTOMER)
- [ ] Verification status filter
- [ ] Account status filter (Active/Deleted)
- [ ] Search by name/email
- [ ] Stat cards (Total, Verified, Unverified, Deleted)
- [ ] Tap → detail screen:
  - User info
  - Roles & permissions
  - Audit trail
  - Actions: Send Reset, Soft Delete, Restore

#### 3.7 Role Management (`more/roles.tsx` + detail)
- [ ] Role list (system + custom)
- [ ] Create custom role
- [ ] Tap → detail screen:
  - Role info
  - Members list
  - Permissions checklist (toggle on/off)
  - Delete (custom only)

### Tier 3 - Monitoring & Investigation

#### 3.8 Audit Logs (`activity.tsx` with tab/segment)
- [ ] Filterable log list:
  - Entity name filter
  - Entity ID search
  - User filter
  - Event type filter
  - Action filter (CREATE/UPDATE/DELETE/RESTORE)
  - Date range picker
- [ ] Expandable rows showing changed fields
- [ ] "PJ Analyze" button:
  - Select logs (checkbox)
  - Add context text
  - Run AI analysis
  - Display summary, timeline, patterns, anomalies

#### 3.9 AI Interaction Logs (`activity.tsx` second tab/segment)
- [ ] Filterable log list:
  - Operation filter
  - Model filter
  - Provider filter
  - Success/failure filter
  - Date range
- [ ] Each row shows: timestamp, operation, model, latency, tokens, success
- [ ] Expandable detail:
  - System prompt
  - User input
  - Raw response
  - Error details
  - Caller info (service/method)

### Tier 4 - Content & Settings Management

#### 3.10 Help Center Admin (`more/help-center.tsx`)
- [ ] Tabbed view: Articles | Categories | FAQs
- [ ] Articles: list, filter by status/audience, search, create/edit/delete
- [ ] Categories: list, create/edit/delete, reorder
- [ ] FAQs: list, create/edit/delete
- [ ] Article editor (simplified for mobile - title, excerpt, body, category, audience, status)

#### 3.11 Service Provider Management (`more/service-providers.tsx`)
- [ ] Providers tab: list, search, filter by certification
- [ ] Offerings tab: list, search, filter by type
- [ ] Data enrichment tab:
  - Filter by blank field
  - Enrich single / bulk enrich
  - View results

#### 3.12 SP Claims (`more/sp-claims.tsx`)
- [ ] List of pending claims
- [ ] Each claim shows: SP name, claimant email, evidence, date
- [ ] Approve / Reject (with notes) actions

#### 3.13 Vendor Pages Admin (`more/vendor-pages.tsx`)
- [ ] List with status filter (DRAFT/PUBLISHED)
- [ ] Search by name/slug
- [ ] Create/edit (display name, slug, offering type, content)
- [ ] Delete
- [ ] Recalculate rankings button

#### 3.14 Billing Overview (`more/billing.tsx`)
- [ ] Read-only list of SP billing accounts
- [ ] Show: SP name, tier, billing status, period end
- [ ] Filter by status

---

## Phase 4: i18n & Polish

### 4.1 New i18n Namespaces
Replace customer namespaces with admin ones:

```
i18n/resources/
├── en/
│   ├── common.json         # Keep - general UI
│   ├── auth.json           # Simplify - admin login only
│   ├── home.json           # Rewrite - admin dashboard
│   ├── settings.json       # Keep mostly
│   ├── notifications.json  # Keep mostly
│   ├── admin.json          # NEW - admin-specific strings
│   ├── support.json        # NEW - support ticket strings
│   ├── users.json          # NEW - user management strings
│   ├── ideas.json          # NEW - ideas/feedback strings
│   ├── providers.json      # NEW - SP management strings
│   ├── logs.json           # NEW - audit & AI log strings
│   └── helpCenter.json     # NEW - help center admin strings
├── es/ (same structure)
└── fr/ (same structure)
```

### 4.2 Branding & Theme
**Brand Colors** (from Redbrick Software logo):
- **Primary**: Crimson Red `#A91D2E` (the handwritten logo color)
- **Background**: White `#FFFFFF`
- **Dark mode background**: Gray-950 `#030712` (keep consistent with Projulous)
- **Dark mode primary**: Lighter red `#E8485C` or rose-400 for dark mode contrast
- **Accent**: Use primary red for buttons, tab indicators, badges, links

**Color Palette Replacement** (in `constants/theme.ts`):
| Projulous (indigo) | Redbrick (crimson) |
|---|---|
| indigo-500 `#6366f1` | crimson `#A91D2E` |
| indigo-300 `#a5b4fc` | rose-300 `#fda4af` |
| indigo-100 `#e0e7ff` | rose-100 `#ffe4e6` |
| indigo-50 `#eef2ff` | rose-50 `#fff1f2` |
| indigo-600 `#4f46e5` | crimson-dark `#8B1825` |

- [ ] Replace all indigo references with crimson/rose palette
- [ ] App icon: Redbrick Software logo on white background (rounded corners)
  - Source: `/Users/brycedeneen/Documents/dev/ta/ta-mobile-backup/src/assets/img/redbricksoftwarediagonal.png`
- [ ] Splash screen: White background, Redbrick Software logo centered
- [ ] Replace all "Projulous" text references with "Redbrick Software"
- [ ] Android notification light color: `#A91D2E` (was `#6366F1`)

### 4.3 Mobile UX Adaptations
- [ ] Swipe gestures for ticket actions (mark resolved, etc.)
- [ ] Pull-to-refresh on all list screens
- [ ] Skeleton loading states
- [ ] Empty states for each list
- [ ] Error states with retry
- [ ] Haptic feedback on actions

---

## Phase 5: Testing & Deployment

### 5.1 Testing
- [ ] Auth: verify SUPER_ADMIN-only login enforcement
- [ ] Each admin screen: data loads, filters work, pagination works
- [ ] CRUD operations: create/edit/delete on each entity
- [ ] Push notifications: admin notifications arrive
- [ ] Offline: graceful degradation
- [ ] Deep links: `redbrickadmin://` scheme works

### 5.2 EAS Build Configuration
- [ ] `eas.json` with development, preview, production profiles
- [ ] TestFlight distribution for iOS
- [ ] Internal distribution for Android
- [ ] Separate from Projulous app on all stores

### 5.3 App Store
- [ ] Public App Store listing (iOS App Store + Google Play Store)
- [ ] App Store metadata: name, description, screenshots, privacy policy
- [ ] App Store icon (1024x1024) from Redbrick logo
- [ ] Privacy policy URL (required for App Store)
- [ ] Note: Login gated to SUPER_ADMIN, so public listing is fine

---

## Implementation Order (Recommended)

| Order | Phase | Effort | Description |
|-------|-------|--------|-------------|
| 1 | 0.1-0.3 | 1-2 days | Clone, strip, rebrand, lock auth |
| 2 | 1.1-1.3 | 1 day | Navigation structure, tab bar, routing |
| 3 | 2.1 | 2-3 days | Data access layer (port from web) |
| 4 | 3.1-3.2 | 2 days | Support tickets + Dashboard (daily use) |
| 5 | 3.3 | 0.5 day | Admin notifications |
| 6 | 3.4-3.5 | 2-3 days | Ideas + SP certification |
| 7 | 3.6-3.7 | 2 days | User & role management |
| 8 | 3.8-3.9 | 2-3 days | Audit + AI logs |
| 9 | 3.10-3.14 | 3-4 days | Help center, SP management, claims, vendor pages, billing |
| 10 | 4.1-4.3 | 1-2 days | i18n, branding, polish |
| 11 | 5.1-5.3 | 1-2 days | Testing, builds, deployment |

**Estimated total: ~3-4 weeks**

---

## Shared Components to Build

These new mobile components will be needed across multiple admin screens:

| Component | Used By |
|-----------|---------|
| `AdminStatCard` | Dashboard, Support, Users, Ideas |
| `FilterChips` | All list screens |
| `AdminListItem` | All list screens |
| `StatusBadge` | Tickets, Ideas, SPs, Billing |
| `DateRangePicker` | Audit logs, AI logs |
| `ExpandableRow` | Audit logs, AI logs |
| `AdminActionSheet` | Ticket actions, SP actions, Idea actions |
| `RichTextEditor` (simplified) | Help center articles |
| `AdminMoreMenu` | "More" tab grid layout |
| `PermissionCheckList` | Role detail |
| `UserInfoCard` | User detail, Ticket detail |
| `SPInfoCard` | SP detail, SP review |

---

## Decisions Made

| # | Question | Decision |
|---|----------|----------|
| 1 | Branding | New Redbrick colors (crimson red `#A91D2E` on white) + Redbrick Software logo |
| 2 | Auth | **OAuth only** (Google + Apple). No email/password login. |
| 3 | Registration | **No registration**. Admin accounts created by other admins on web. |
| 4 | Forgot Password | **Removed**. OAuth-only means no password to reset. |
| 5 | Tab layout | **4 bottom tabs + "More" menu** (Option B). Dashboard, Support, Activity, Settings. |
| 6 | Distribution | **Public App Store** (iOS + Android). Login gated to SUPER_ADMIN. |

## Open Questions (Lower Priority)

7. **Billing actions**: Read-only overview, or ability to modify billing from mobile?
8. **Help Center editor**: Full markdown editor on mobile, or simplified form fields only?
9. **Vendor page editor**: Full content editing on mobile, or just metadata?
10. **Push notifications**: Same backend push token registration, or separate admin notification channel?
