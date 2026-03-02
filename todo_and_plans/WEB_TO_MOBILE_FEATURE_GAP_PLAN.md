# Web-to-Mobile Feature Gap Analysis & Implementation Plans

## Context

A comprehensive comparison of projulous-web vs projulous-mobile reveals **22 significant feature gaps** where the web app has functionality that the mobile app completely lacks. The largest gap is the **Service Provider experience** — web has a full SP portal (onboarding, dashboard, offerings, team, billing, certification, tickets) while mobile has essentially zero SP-specific features beyond a non-functional Schedule stub tab.

This plan documents every gap, prioritizes them, and provides implementation plans with effort estimates and dependencies.

---

## Gap Summary by Category

### A. Service Provider Features (8 gaps — CRITICAL)
### B. Customer Features (7 gaps — HIGH/MEDIUM)
### C. Public/Discovery Features (5 gaps — MEDIUM)
### D. Partially Implemented Features (2 gaps — HIGH)

---

## Priority Tiers

| Tier | Priority | Criteria |
|------|----------|----------|
| **P0** | Critical | SPs cannot effectively use the mobile app without these |
| **P1** | High | Core customer features missing from mobile |
| **P2** | Medium | Discovery/engagement features that improve mobile experience |
| **P3** | Low | Nice-to-have parity or features with web-browser workarounds |

---

## A. SERVICE PROVIDER GAPS (P0 — Critical)

### A1. SP Onboarding Wizard
**Web:** 4-step wizard (Business Profile → Offerings → Plan Selection → Review & Complete)
**Mobile:** Nothing — SP logs in and sees generic home screen

**Plan:**
- 4 screens matching web steps: `app/sp/onboarding/index.tsx` (step router), `business-profile.tsx`, `offerings.tsx`, `plan-selection.tsx`, `review.tsx`
- Step indicator component (reuse NativeWind progress dots pattern)
- Auto-redirect from home if `onboardingCompleted === false` (matches web behavior)
- Data access: `dataAccess/serviceProvider/spOnboarding.da.ts`
- Success screen with haptic feedback + confetti animation
- **Dependencies:** None — backend APIs already exist
- **Effort:** 3-4 days
- **Key files to reference:** `projulous-web/app/routes/serviceProviders/onboarding/spOnboarding.route.tsx`

### A2. SP Dashboard (Home Screen for SPs)
**Web:** Stat cards (Active Projects, Team Members, Pending Invites, Offerings), company profile card with certification/tier/rating badges, quick links, recent projects table, offerings grid
**Mobile:** Generic home screen identical to customer (greeting + recent projects + maintenance widget)

**Plan:**
- Modify `app/(tabs)/index.tsx` to render SP-specific dashboard when `userType === SERVICE_PROVIDER`
- Components: `SPStatCards`, `SPCompanyProfileCard`, `SPQuickActions`, `SPRecentProjects`, `SPOfferingsPreview`
- Stat cards link to respective SP management screens (offerings, team, etc.)
- Company name prompt modal if blank (matches web)
- Data access: `dataAccess/serviceProvider/spDashboard.da.ts`
- **Dependencies:** A1 (onboarding should complete first so dashboard has data)
- **Effort:** 2-3 days
- **Key files to reference:** `projulous-web/app/routes/serviceProviders/dashboard/spDashboard.route.tsx`

### A3. SP Offerings Management
**Web:** Full CRUD table with search, filter by type, pagination, verified status badges
**Mobile:** Nothing

**Plan:**
- Screens: `app/sp/offerings/index.tsx` (list), `app/sp/offerings/form.tsx` (create/edit)
- List with search, type filter chips (like appliance list pattern), pull-to-refresh
- Offering cards: name, type, city + state, radius, verified badge
- Swipe-to-delete with confirmation
- Form: name, offering type picker, center city, postal code, radius, description
- Data access: `dataAccess/serviceProvider/offerings.da.ts`
- **Dependencies:** None — backend APIs exist
- **Effort:** 2-3 days
- **Key files to reference:** `projulous-web/app/routes/serviceProviders/offerings/spOfferings.route.tsx`

### A4. SP Team Management
**Web:** Team members table, invite by email, role management, pending invites, deactivate member, team member detail
**Mobile:** Nothing

**Plan:**
- Screens: `app/sp/team/index.tsx` (list + pending invites), `app/sp/team/[userId].tsx` (detail), `app/sp/team/invite.tsx` (invite form)
- Two sections: Active Members + Pending Invites (collapsible)
- Member cards: avatar, name, email, role badge (Admin/Member), status
- Admin actions: invite, deactivate, change role, cancel invite, resend invite
- Role-based visibility (only ADMIN team role sees management actions)
- Data access: `dataAccess/serviceProvider/team.da.ts`
- **Dependencies:** None — backend APIs exist
- **Effort:** 3-4 days
- **Key files to reference:** `projulous-web/app/routes/serviceProviders/team/teamManagement.route.tsx`

### A5. SP Billing & Subscription
**Web:** Current plan display, Stripe-powered plan selector (Free/Starter/Pro/Pinnacle), invoice history, cancel subscription, billing portal link
**Mobile:** Nothing

**Plan:**
- Screen: `app/sp/billing/index.tsx`
- Current plan card with tier badge + price
- "Change Plan" button → opens Stripe checkout in in-app browser (WebBrowser.openBrowserAsync)
- Invoice history list (date, amount, status badge, PDF link opens in browser)
- Cancel subscription with confirmation alert
- Billing portal external link
- Handle Stripe checkout return via deep link
- Data access: `dataAccess/serviceProvider/billing.da.ts`
- **Dependencies:** None — backend Stripe APIs exist
- **Effort:** 2-3 days
- **Key files to reference:** `projulous-web/app/routes/serviceProviders/billing/billing.route.tsx`

### A6. SP Certification
**Web:** Certification status display, verification questionnaire (YES/NO/N_A answers), submit for review, recertification request, history log
**Mobile:** Nothing

**Plan:**
- Screen: `app/sp/certification/index.tsx`
- Status card with certification status badge (8 possible statuses)
- Questionnaire section: scrollable list of questions with radio buttons (Yes/No/N_A) + optional notes per question
- Action buttons based on status: Submit for Certification, Request Recertification, Update Responses
- Certification history timeline
- Admin team role check (only ADMIN can submit)
- Data access: `dataAccess/serviceProvider/certification.da.ts`
- **Dependencies:** None — backend APIs exist
- **Effort:** 2-3 days
- **Key files to reference:** `projulous-web/app/routes/serviceProviders/certification/spCertification.route.tsx`

### A7. SP Support Tickets
**Web:** Ticket list with status/priority badges, create ticket, detail view with activity log, close ticket
**Mobile:** Nothing for SPs (or customers — see B2)

**Plan:**
- Screens: `app/sp/tickets/index.tsx` (list), `app/sp/tickets/[ticketId].tsx` (detail), `app/sp/tickets/create.tsx` (form)
- List: search, filter by status, ticket cards with subject, status/priority badges, date
- Detail: subject, description, status/priority badges, activity log (chronological), close ticket button
- Create: subject, description, priority, category pickers
- Data access: `dataAccess/serviceProvider/tickets.da.ts`
- **Dependencies:** Shares pattern with customer tickets (B2) — build together
- **Effort:** 2-3 days (shared with B2 — total 3-4 days for both)
- **Key files to reference:** `projulous-web/app/routes/serviceProviders/tickets/spTicketList.route.tsx`

### A8. SP Registration (Join as SP)
**Web:** Dedicated `/service-providers/join` with company name field, supports `?tier` and `?claimToken` params
**Mobile:** Only has generic customer registration

**Plan:**
- Screen: `app/(auth)/register-sp.tsx`
- Same fields as customer register + Company Name (required)
- Link from login screen: "Are you a service provider? Join here"
- Support `tier` and `claimToken` route params
- Registers with SERVICE_PROVIDER role
- After registration → confirm registration → login → SP onboarding wizard
- **Dependencies:** A1 (onboarding wizard should exist for the post-registration flow)
- **Effort:** 1 day
- **Key files to reference:** `projulous-web/app/routes/serviceProviders/join/join.route.tsx`

### A-Nav. SP Navigation Structure
**Web:** Sidebar has SP section: Dashboard, Offerings, Team, Billing, Tickets + Certification link
**Mobile:** SP has tabs: Home, Projects, PJ, Schedule, Settings — no SP management access

**Plan:**
- Add "SP Management" section to Settings screen with navigation rows:
  - My Business (dashboard/profile) → `app/sp/dashboard`
  - My Offerings → `app/sp/offerings`
  - Team → `app/sp/team`
  - Billing → `app/sp/billing`
  - Certification → `app/sp/certification`
  - Support Tickets → `app/sp/tickets`
- OR: Replace non-functional Schedule tab with "Business" tab containing these links
- **Effort:** 0.5 days (included in A2 dashboard work)

---

## B. CUSTOMER FEATURE GAPS

### B1. Help Center (P1 — High)
**Web:** Full help center with search, category cards, articles by audience (Customer/SP), article detail, contact/ticket form, ideas link
**Mobile:** Nothing

**Plan:**
- Screens: `app/help-center/index.tsx` (home), `app/help-center/article/[slug].tsx` (article detail), `app/help-center/contact.tsx` (contact form)
- Home: search bar, audience toggle (Customer/SP), category cards grid, popular articles list
- Article detail: rendered content, breadcrumb back
- Contact: subject, message, submit (creates ticket)
- Navigation: add "Help Center" row to Settings screen
- Data access: `dataAccess/helpCenter/helpCenter.da.ts` (may already exist — check)
- **Dependencies:** None — backend APIs exist
- **Effort:** 2-3 days
- **Key files to reference:** `projulous-web/app/routes/helpCenter/helpCenter.route.tsx`

### B2. Support Tickets — Customer (P1 — High)
**Web:** Ticket list, create ticket, ticket detail with activity log
**Mobile:** Nothing

**Plan:**
- Screens: `app/tickets/index.tsx` (list), `app/tickets/[ticketId].tsx` (detail), `app/tickets/create.tsx` (form)
- Shared components with SP tickets (A7) — extract `TicketCard`, `TicketActivityLog`, `TicketStatusBadge`, `TicketPriorityBadge` into `components/tickets/`
- Navigation: add "My Tickets" row to Settings screen
- Data access: `dataAccess/customer/tickets.da.ts`
- **Dependencies:** Build alongside A7 for shared components
- **Effort:** 2 days (shared effort with A7)
- **Key files to reference:** `projulous-web/app/routes/customers/tickets/ticketList.route.tsx`

### B3. Maintenance Overview — Aggregate View (P1 — High)
**Web:** Dedicated `/customers/maintenance` with stat cards (Overdue/Due Soon/On Track), filters by appliance and status, full reminder list with actions
**Mobile:** Only a small 3-item widget on home screen

**Plan:**
- Screen: `app/maintenance/index.tsx` (full overview)
- Summary stat cards at top: Overdue (red), Due Soon (amber), On Track (green) — tappable to filter
- Filter: appliance picker, status picker
- Full reminder list: name, appliance name (tappable to appliance detail), next due, last completed, cost, status badge
- Actions: mark complete (navigate to maintenance-complete screen), edit, delete
- Navigation: add dedicated row in Settings or as a section accessible from home "See All" link
- Data access: extend existing `maintenanceReminder.da.ts` with `getAllReminders()` aggregate query
- **Dependencies:** None — backend APIs exist
- **Effort:** 1.5-2 days
- **Key files to reference:** `projulous-web/app/routes/customers/maintenance/maintenanceOverview.route.tsx`

### B4. Ideas Board (P2 — Medium)
**Web:** Browse ideas, vote, comment, submit new ideas, filter by category/status, sort, trending topics
**Mobile:** Nothing

**Plan:**
- Screens: `app/ideas/index.tsx` (list), `app/ideas/[ideaId].tsx` (detail), `app/ideas/submit.tsx` (form)
- List: sort tabs (All/Trending/Most Voted/Newest), category filter, search, idea cards with vote count
- Detail: full idea content, vote button, comment section
- Submit: title, description, category picker
- Navigation: add "Ideas & Feedback" row to Settings or Help Center
- Data access: `dataAccess/helpCenter/ideas.da.ts`
- **Dependencies:** None — backend APIs exist
- **Effort:** 2-3 days
- **Key files to reference:** `projulous-web/app/routes/helpCenter/ideasBoard.route.tsx`

### B5. Customer Billing (P2 — Medium)
**Web:** Customer billing management page
**Mobile:** Nothing

**Plan:**
- Screen: `app/settings/billing.tsx`
- Basic billing info display
- Navigation: add "Billing" row to Settings screen
- Data access: `dataAccess/customer/billing.da.ts`
- **Dependencies:** None
- **Effort:** 1 day
- **Key files to reference:** `projulous-web/app/routes/customers/billing/billing.route.tsx`

### B6. Project Quotes Tab (P2 — Medium)
**Web:** 5-tab project detail includes Quotes tab
**Mobile:** Only 4 tabs (Overview, Plan, Budget, Team) — no Quotes

**Plan:**
- Add 5th tab "Quotes" to `app/project/[projectId].tsx`
- Components: `QuotesTab.tsx` with quote cards per phase
- Quote detail with SP info, amount, status
- Data access: extend `project.da.ts` with quote methods
- **Dependencies:** Quote management feature completeness on backend
- **Effort:** 1.5-2 days

### B7. MCP API Keys (P3 — Low / Deferred)
**Web:** Settings has MCP API key management section
**Mobile:** Nothing — API keys are a developer/power-user feature not suited for mobile

**Plan:** Defer to V2
- **Effort:** N/A (deferred)

---

## C. PUBLIC/DISCOVERY FEATURE GAPS

### C1. Browse Services Page (P2 — Medium)
**Web:** `/services` — grid of all published vendor categories with icons
**Mobile:** Nothing — relies solely on PJ AI chat for service discovery

**Plan:**
- Screen: `app/services/index.tsx` (browse grid)
- Grid of vendor page configs with icon, display name, subtitle
- Tap to navigate to vendor landing page (C2)
- Navigation: accessible from home screen or a "Browse Services" button
- Data access: `dataAccess/services/vendorPages.da.ts`
- **Dependencies:** C2 (vendor detail pages) for the tap-through experience
- **Effort:** 1 day
- **Key files to reference:** `projulous-web/app/routes/services/browseAll.route.tsx`

### C2. Vendor Landing Pages (P2 — Medium)
**Web:** Dynamic pages per service category — hero, zip search, provider results, service type filters, showcase, FAQs, CTA
**Mobile:** Nothing

**Plan:**
- Screen: `app/services/[vendorType].tsx`
- Hero with service name + stat badges
- Zip code search input with geolocation
- Provider result cards (reuse pattern from PJ chat provider cards)
- Service type filter chips
- FAQ accordion section
- "Get Quote" button → opens PJ chat with pre-filled context
- Data access: `dataAccess/services/vendorLanding.da.ts`
- **Dependencies:** C1 for navigation; C3 for provider detail tap-through
- **Effort:** 2-3 days
- **Key files to reference:** `projulous-web/app/routes/services/$vendorType.route.tsx`

### C3. Service Provider Detail Page (P2 — Medium)
**Web:** Individual SP profile — name, rating, location, about, services list, contact info, get quote, save/unsave
**Mobile:** Only sees SP as small cards in PJ chat results — no standalone profile view

**Plan:**
- Screen: `app/services/provider/[serviceProviderId].tsx`
- Full SP profile: name, verified/pending badges, star rating, location, about section, offerings list, contact info (email, phone, website)
- "Get Quote" button → opens PJ chat
- Save/Unsave button (customer only)
- Data access: `dataAccess/services/serviceProviderDetail.da.ts`
- **Dependencies:** None — backend APIs exist
- **Effort:** 1.5-2 days
- **Key files to reference:** `projulous-web/app/routes/services/serviceProviderDetail.route.tsx`

### C4. Project Showcase (P3 — Low)
**Web:** Browse published showcase projects + individual project stories
**Mobile:** Nothing

**Plan:**
- Screens: `app/showcase/index.tsx` (browse), `app/showcase/[id].tsx` (story detail)
- Browse: category filter, sort, search, project cards
- Detail: full story content with images
- Navigation: accessible from home or services area
- **Dependencies:** SP Showcase Self-Publishing plan (not yet started on web either)
- **Effort:** 2 days
- **Key files to reference:** `projulous-web/app/routes/projects/projectShowcase.route.tsx`

### C5. "Why Join as SP" Marketing Page (P3 — Low / Deferred)
**Web:** Marketing landing page with benefits, pricing table, testimonials
**Mobile:** Nothing

**Plan:** Defer — marketing pages are better suited to web. Mobile SP registration (A8) can include brief benefits. Alternatively, link to web page via in-app browser.
- **Effort:** N/A (deferred or 0.5 days for in-app browser link)

---

## D. PARTIALLY IMPLEMENTED FEATURES

### D1. Push Notification Delivery (P0 — Critical)
**Web:** SSE-based real-time notifications (working)
**Mobile:** Can receive push notifications but backend NEVER sends them — tokens stored in DB unused

**Plan:** Already documented in `PUSH_NOTIFICATIONS_AUTH_APPLE_PLAN.md` Phase 1
- Create `PushNotificationService` wrapping Expo Push API
- Hook into `NotificationService.createNotification()` as fire-and-forget
- Push token cleanup on logout
- Respect notification preference toggles
- **Dependencies:** None — mobile infrastructure ready, just needs backend sending
- **Effort:** 2-3 days
- **Key files:** `projulous-svc/src/notification/` module

### D2. Schedule Tab — Functional Implementation (P1 — High)
**Web:** No direct equivalent yet (scheduling feature deferred ~16 weeks)
**Mobile:** Non-functional stub showing Mon/Tue/Wed with "No Appointments"

**Plan:** Two options:
- **Option A (Recommended):** Replace stub with SP Management hub linking to offerings, team, billing, certification, tickets — makes the tab useful NOW
- **Option B:** Remove tab entirely until scheduling feature is built (~16 weeks deferred)
- **Effort:** 0.5 days for Option A, included in A-Nav work

---

## Implementation Roadmap

### Sprint 1: SP Foundation (Week 1-2) — ~10 days
| # | Feature | Effort | Priority |
|---|---------|--------|----------|
| A1 | SP Onboarding Wizard | 3-4d | P0 |
| A8 | SP Registration | 1d | P0 |
| A2 | SP Dashboard + Nav | 2.5-3d | P0 |
| A-Nav | SP Navigation (Settings rows or tab replacement) | 0.5d | P0 |
| D2 | Schedule Tab → SP Management Hub | 0.5d | P1 |

### Sprint 2: SP Management (Week 3-4) — ~10 days
| # | Feature | Effort | Priority |
|---|---------|--------|----------|
| A3 | SP Offerings CRUD | 2-3d | P0 |
| A4 | SP Team Management | 3-4d | P0 |
| A5 | SP Billing | 2-3d | P0 |
| A6 | SP Certification | 2-3d | P0 |

### Sprint 3: Support & Help (Week 5-6) — ~8 days
| # | Feature | Effort | Priority |
|---|---------|--------|----------|
| D1 | Push Notification Delivery | 2-3d | P0 |
| A7+B2 | Tickets (SP + Customer) | 3-4d | P0/P1 |
| B1 | Help Center | 2-3d | P1 |

### Sprint 4: Customer Enhancements (Week 7-8) — ~7 days
| # | Feature | Effort | Priority |
|---|---------|--------|----------|
| B3 | Maintenance Overview | 1.5-2d | P1 |
| B4 | Ideas Board | 2-3d | P2 |
| B5 | Customer Billing | 1d | P2 |
| B6 | Project Quotes Tab | 1.5-2d | P2 |

### Sprint 5: Discovery Features (Week 9-10) — ~6 days
| # | Feature | Effort | Priority |
|---|---------|--------|----------|
| C1 | Browse Services | 1d | P2 |
| C2 | Vendor Landing Pages | 2-3d | P2 |
| C3 | SP Detail Page | 1.5-2d | P2 |
| C4 | Project Showcase | 2d | P3 |

### Deferred
| # | Feature | Reason |
|---|---------|--------|
| B7 | MCP API Keys | Power-user feature, not suited for mobile |
| C5 | "Why Join as SP" page | Marketing page, web link sufficient |

---

## Total Effort Estimate

| Category | Items | Estimated Days |
|----------|-------|----------------|
| SP Features (P0) | 9 items | ~18-22 days |
| Customer Features (P1) | 4 items | ~8-11 days |
| Discovery Features (P2-P3) | 5 items | ~7-10 days |
| Push Notifications (P0) | 1 item | ~2-3 days |
| **Total** | **19 items** | **~35-46 days** |

---

## Cross-Cutting Concerns

1. **i18n**: All new screens need EN/ES/FR translations in `projulous-mobile/translations/` across relevant namespaces
2. **Theme**: All screens must support dark/light/system themes via NativeWind
3. **Haptics**: iOS haptic feedback on key actions (save, delete, complete)
4. **Pull-to-refresh**: All list screens
5. **Error states**: Empty states, error fallbacks, loading skeletons
6. **Data access pattern**: Follow existing `dataAccess/` class pattern with `ApiClient`
7. **Path alias**: Use `@/` prefix for all imports

---

## Already Documented Plans (No Duplication Needed)

These gaps are already covered by existing plans in `todo_and_plans/`:
- Push Notification Delivery → `PUSH_NOTIFICATIONS_AUTH_APPLE_PLAN.md` Phase 1
- Apple Sign-In → `PUSH_NOTIFICATIONS_AUTH_APPLE_PLAN.md` Phase 3
- Project Collaborator Invite fixes → `PROJECT_COLLABORATOR_INVITE_PLAN.md`
- Scheduling/Booking (major feature) → `scheduling/SCHEDULING_FEATURE_PLAN.md` (deferred ~16 weeks)

---

## Verification

After each sprint:
1. Run `npm run lint` in projulous-mobile
2. Test on iOS Simulator (`npx expo start --ios`)
3. Test on Android Emulator (`npx expo start --android`)
4. Verify each feature matches web functionality
5. Test i18n in all 3 languages
6. Test dark mode
7. Run `npx expo start` and verify no TypeScript errors
