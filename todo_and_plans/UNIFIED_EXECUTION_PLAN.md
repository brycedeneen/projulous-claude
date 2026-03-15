# Unified Execution Plan — Remaining Features

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete 11 remaining features across mobile and web, sequenced for optimal dependency ordering and minimal conflicts.

**Architecture:** Mobile features follow existing patterns (Expo Router file-based routing, static DA classes with GraphQL reads + REST writes, NativeWind styling, i18n EN/ES/FR). Web features follow existing patterns (React Router v7, Tailwind CSS v4, data access classes). All backend APIs already exist — no backend changes needed for mobile work.

**Tech Stack:** Expo SDK 54, React Native 0.81, NativeWind v5, React Router v7, Tailwind CSS v4, NestJS, TypeORM, Apollo GraphQL

---

## Dependency Graph

```
Batch 1 (Quick Wins)          Batch 2 (Web)              Batch 3 (Backend)
├─ SP Billing Wiring (1h)     ├─ SP Showcase Phase 1     ├─ Planner Sprint 7
├─ SP Offerings CRUD (2-3d)   │  (shared-dto)            │  (shared-dto + svc)
                               ├─ SP Showcase Phase 2
                               │  (backend)
                               ├─ SP Showcase Phase 3
                               │  (web frontend)
                               └─ SP Showcase Phase 4
                                  (homepage wiring)

Batch 4 (Mobile Customer)     Batch 5 (Mobile Discovery)
├─ Maintenance Overview        ├─ Browse Services
├─ Ideas Board                 ├─ Vendor Landing Pages (depends on Browse)
├─ Customer Billing            └─ SP Detail Page (depends on Vendor Landing)
└─ Project Quotes Tab
```

**Batches 1-3 can run in parallel.** Batch 4 and 5 can run in parallel with each other, but Batch 5 is internally sequential (C1 → C2 → C3).

**Shared-DTO conflict note:** Batches 2 and 3 both modify `projulous-shared-dto-node`. If run in parallel, coordinate the build+push. Recommended: do Batch 2's shared-dto first (Phase 1), then Batch 3's shared-dto, then a single build+push.

---

## Batch 1: Mobile SP Quick Wins

### Task 1.1: Wire SP Billing in Settings (~1 hour)

The billing screens, components, and DA all exist. The settings menu just doesn't link to them.

**Files:**
- Modify: `projulous-mobile/app/(tabs)/settings.tsx`

- [ ] **Step 1:** In `settings.tsx`, find the SP management items array (~line 211-217). Add `onPress` to the billing item:

```typescript
// Change this:
{ key: 'billing', labelKey: 'settings.billing', icon: CreditCardMultipleStroke },
// To this:
{ key: 'billing', labelKey: 'settings.billing', icon: CreditCardMultipleStroke, onPress: () => router.push('/sp/billing') },
```

- [ ] **Step 2:** Verify on simulator — tap Settings → Billing → should show billing screen with account status and invoices.

- [ ] **Step 3:** Commit: `fix(mobile): wire SP billing navigation in settings`

---

### Task 1.2: SP Offerings CRUD (2-3 days)

SPs can manage their service offerings. Backend APIs exist. Web reference: `projulous-web/app/routes/serviceProviders/offerings/spOfferings.route.tsx`. Onboarding already has `offering-form-modal.tsx` component.

**Files:**
- Create: `projulous-mobile/dataAccess/serviceProvider/spOfferings.da.ts`
- Create: `projulous-mobile/app/sp/offerings/_layout.tsx`
- Create: `projulous-mobile/app/sp/offerings/index.tsx`
- Create: `projulous-mobile/app/sp/offerings/form.tsx`
- Modify: `projulous-mobile/app/(tabs)/settings.tsx` (wire navigation)
- Modify: `projulous-mobile/i18n/resources/en/serviceProvider.json` (add offerings keys)
- Modify: `projulous-mobile/i18n/resources/es/serviceProvider.json`
- Modify: `projulous-mobile/i18n/resources/fr/serviceProvider.json`

#### 1.2.1: Data Access Layer

- [ ] **Step 1:** Create `projulous-mobile/dataAccess/serviceProvider/spOfferings.da.ts`

**GraphQL query** (reference web's `spOfferings.da.tsx`):
```
getServiceProviderOfferingsPaginated(serviceProviderId, skip, take) {
  serviceProviderOfferingId, name, description, offeringType, verifiedStatus,
  centerPointCityName, centerPointStateName, centerPointPostalCode,
  serviceRadiusMiles, standardFields { createdDate, updatedDate }
}
```

**REST endpoints** (SP ID from SecureStoreService):
- POST `/v1/service-providers/{spId}/service-provider-offerings` — create
- PUT `/v1/service-providers/{spId}/service-provider-offerings/{offeringId}` — update
- DELETE `/v1/service-providers/{spId}/service-provider-offerings/{offeringId}` — delete

Follow the pattern in `projulous-mobile/dataAccess/customer/customerProject.da.ts` — static class methods, GraphQL for reads, REST for writes, SecureStoreService for IDs.

- [ ] **Step 2:** Commit: `feat(mobile): add SP offerings data access layer`

#### 1.2.2: Offerings List Screen

- [ ] **Step 3:** Create `projulous-mobile/app/sp/offerings/_layout.tsx` — simple Stack layout (reference `projulous-mobile/app/sp/team/_layout.tsx`).

- [ ] **Step 4:** Create `projulous-mobile/app/sp/offerings/index.tsx` — Offerings list screen.

**Pattern:** Follow `projulous-mobile/app/tickets/index.tsx` for list screen structure.

**Features:**
- `useFocusEffect` to load offerings on screen focus
- Search bar (filter by name, city)
- OfferingType filter chips (horizontal scroll)
- FlatList of offering cards showing: name, offeringType badge, city+state, radius, verified status badge
- Pull-to-refresh
- FAB or header button "Add Offering" → `router.push('/sp/offerings/form')`
- Swipe-to-delete with `confirm-delete.ts` utility
- Empty state when no offerings
- i18n via `useTranslation('serviceProvider')`

**Verified status badge colors** (reference web):
- `VERIFIED` → green
- `PENDING` → amber
- `NOT_VERIFIED` → gray

- [ ] **Step 5:** Commit: `feat(mobile): add SP offerings list screen`

#### 1.2.3: Offering Form Screen

- [ ] **Step 6:** Create `projulous-mobile/app/sp/offerings/form.tsx` — Create/edit offering form.

**Pattern:** Follow `projulous-mobile/app/appliance/form.tsx` for form screen structure.

**Route params:** `offeringId?` (undefined = create, present = edit)

**Form fields:**
- Name (text input, required)
- Offering Type (picker/select from `OfferingTypeENUM`, required)
- Description (textarea)
- Center Point City (text input)
- Center Point State (text input)
- Center Point Postal Code (text input)
- Service Radius Miles (number input)

**Behavior:**
- If `offeringId` present: load existing offering, pre-fill form
- Save button calls create or update based on mode
- Success toast + `router.back()`
- Haptic feedback on save (iOS)

- [ ] **Step 7:** Commit: `feat(mobile): add SP offering create/edit form`

#### 1.2.4: Wire Navigation + i18n

- [ ] **Step 8:** In `settings.tsx`, add `onPress` to the offerings item:
```typescript
{ key: 'myOfferings', labelKey: 'settings.myOfferings', icon: BoxClosedStroke, onPress: () => router.push('/sp/offerings') },
```

- [ ] **Step 9:** Add i18n keys to `serviceProvider.json` for EN/ES/FR:
```json
"offerings": {
  "title": "My Offerings",
  "addOffering": "Add Offering",
  "editOffering": "Edit Offering",
  "noOfferings": "No offerings yet",
  "noOfferingsMessage": "Add your first service offering to start receiving leads.",
  "deleteConfirm": "Are you sure you want to delete this offering?",
  "name": "Offering Name",
  "type": "Offering Type",
  "description": "Description",
  "city": "City",
  "state": "State",
  "postalCode": "Postal Code",
  "radius": "Service Radius (miles)",
  "verified": "Verified",
  "pending": "Pending",
  "notVerified": "Not Verified",
  "saved": "Offering saved",
  "deleted": "Offering deleted"
}
```

- [ ] **Step 10:** Verify on simulator: Settings → My Offerings → list loads → Add → form works → Edit → Save → Delete.

- [ ] **Step 11:** Commit: `feat(mobile): wire SP offerings navigation and i18n`

---

## Batch 2: SP Showcase Self-Publishing (Web)

Full detailed plan in `todo_and_plans/SP_SHOWCASE_SELF_PUBLISHING_PLAN.md`. This summary tracks execution order. **Requires shared-dto build + migration.**

### Task 2.1: Shared DTO Changes

**Files:**
- Create: `projulous-shared-dto-node/shared/enums/showcaseProjectStatus.enum.ts`
- Create: `projulous-shared-dto-node/showcase/showcaseProjectPhoto.entity.ts`
- Modify: `projulous-shared-dto-node/showcase/showcaseProject.entity.ts`
- Modify: `projulous-shared-dto-node/showcase/index.ts`
- Modify: `projulous-shared-dto-node/shared/enums/index.ts`

- [ ] **Step 1:** Create `ShowcaseProjectStatusENUM` (DRAFT, PUBLISHED). Export from `shared/enums/index.ts`. Do NOT call `registerEnumType()` in the enum file (browser safety).

- [ ] **Step 2:** Create `ShowcaseProjectPhoto` entity following `customer/appliancePhoto.entity.ts` pattern. Fields: showcaseProjectPhotoId (PK), s3Key, originalFilename, mimeType, fileSizeBytes, isPrimary, displayOrder, ManyToOne → ShowcaseProject, ManyToOne → ServiceProvider, standardFields.

- [ ] **Step 3:** Update `ShowcaseProject` entity: add `status` (ShowcaseProjectStatusENUM, default DRAFT), `offeringType` (OfferingTypeENUM, nullable), `postalCode` (varchar 16, nullable), OneToMany → ShowcaseProjectPhoto. Register `ShowcaseProjectStatusENUM` with `registerEnumType()` in the entity file. Add `CreateShowcaseProjectSpDTO` and `UpdateShowcaseProjectSpDTO`.

- [ ] **Step 4:** Update barrel exports in `showcase/index.ts`.

- [ ] **Step 5:** Build shared-dto: `cd projulous-shared-dto-node && npm run buildProd`

- [ ] **Step 6:** Commit shared-dto changes, push to git.

- [ ] **Step 7:** Install in svc: `cd projulous-svc && npm install projulous-shared-dto-node`

- [ ] **Step 8:** Commit: `feat(shared-dto): add ShowcaseProjectPhoto entity and status enum`

### Task 2.2: Backend — Entity Registration + Migration

**Files:**
- Modify: `projulous-svc/src/app.module.ts` (add ShowcaseProjectPhoto to entities)
- Modify: `projulous-svc/src/data-source.ts` (add ShowcaseProjectPhoto to entities)
- Modify: `projulous-svc/src/showcase/showcase.module.ts` (add ShowcaseProjectPhoto, ServiceProvider, ServiceProviderOffering to entities)

- [ ] **Step 1:** Register `ShowcaseProjectPhoto` in all 3 places.

- [ ] **Step 2:** Generate migration: `npm run migration:generate -- src/migrations/AddShowcaseProjectStatusAndPhotos`

- [ ] **Step 3:** Review migration SQL — should include CREATE TYPE for status enum, ALTER TABLE for new columns, CREATE TABLE for photos. Manually add data migration: `UPDATE "ShowcaseProjects" SET status = 'PUBLISHED' WHERE status IS NULL` (so existing rows are visible).

- [ ] **Step 4:** Commit: `feat(svc): register ShowcaseProjectPhoto entity and generate migration`

### Task 2.3: Backend — Photo Service + Controller

**Files:**
- Create: `projulous-svc/src/showcase/services/showcaseProjectPhoto.service.ts`
- Create: `projulous-svc/src/showcase/controllers/showcaseProjectPhoto.controller.ts`
- Modify: `projulous-svc/src/utils/storage/s3Storage.service.ts` (add buildShowcasePhotoKey)
- Modify: `projulous-svc/src/showcase/showcase.module.ts`

Follow `appliancePhoto.service.ts` and `appliancePhoto.controller.ts` patterns exactly.

- [ ] **Step 1:** Add `buildShowcasePhotoKey` to S3 storage service. Pattern: `service-providers/{spId}/showcase/{showcaseProjectId}/{fileId}-{filename}`

- [ ] **Step 2:** Create `ShowcaseProjectPhotoService` with methods: getPhotosForShowcaseProject, uploadPhoto (max 5, verify ownership + tier), deletePhoto, setPrimaryPhoto.

- [ ] **Step 3:** Create photo REST controller at `v1/service-providers/showcase-projects/:showcaseProjectId/photos` with GET, POST (FileInterceptor, 10MB, jpeg/png/webp/heic), DELETE /:photoId, PATCH /:photoId/primary.

- [ ] **Step 4:** Register in showcase module.

- [ ] **Step 5:** Commit: `feat(svc): add showcase project photo service and controller`

### Task 2.4: Backend — SP Showcase Service + Controller

**Files:**
- Modify: `projulous-svc/src/showcase/services/showcaseProject.service.ts`
- Create: `projulous-svc/src/showcase/controllers/showcaseProjectSp.controller.ts`
- Modify: `projulous-svc/src/showcase/resolvers/showcaseProject.resolver.ts`
- Modify: `projulous-svc/src/shared/events/eventType.enum.ts`

- [ ] **Step 1:** Add SP-specific methods to `showcaseProject.service.ts`: getMyShowcaseProjects, getMyShowcaseProject, createShowcaseProjectAsSp (tier check PRO/PINNACLE, validate offeringType against SP offerings, auto-slug, auto-populate provider fields), updateShowcaseProjectAsSp, deleteShowcaseProjectAsSp. Update `getPublishedShowcaseProjects` to filter by PUBLISHED status, accept limit + offeringType params.

- [ ] **Step 2:** Create SP REST controller at `v1/service-providers/showcase-projects` with GET, GET/:id, POST, PATCH/:id, DELETE/:id. Use `@Permissions(PermissionENUM.SHOWCASE_CREATE)` etc.

- [ ] **Step 3:** Add event types: SHOWCASE_PROJECT_PHOTO_UPLOAD, SHOWCASE_PROJECT_PHOTO_DELETE.

- [ ] **Step 4:** Update GraphQL resolver: add `limit` arg to getPublishedShowcaseProjects, filter by PUBLISHED, add photos field resolver.

- [ ] **Step 5:** Commit: `feat(svc): add SP showcase self-service endpoints`

### Task 2.5: Backend — AI Feedback Service

**Files:**
- Create: `projulous-svc/src/showcase/services/showcaseProjectAI.service.ts`
- Create: `projulous-svc/src/showcase/controllers/showcaseProjectAI.controller.ts`
- Modify: `projulous-svc/src/projulousAI/constants/aiInteractionConstants.ts`
- Modify: `projulous-svc/src/projulousAI/prompts/prompts.config.ts`

- [ ] **Step 1:** Add `SHOWCASE_CONTENT_FEEDBACK` to AIOperationENUM. Add `showcaseContentFeedback` prompt to prompts.config.ts.

- [ ] **Step 2:** Create `ShowcaseProjectAIService` following `feedbackAI.service.ts` pattern. Uses Gemini Flash, temperature 0.3, returns structured JSON (overallScore, strengths, improvements, suggestions).

- [ ] **Step 3:** Create AI controller at `POST /v1/service-providers/showcase-projects/:id/ai-feedback`. Requires PRO/PINNACLE tier.

- [ ] **Step 4:** Register in showcase module.

- [ ] **Step 5:** Commit: `feat(svc): add AI writing feedback for showcase posts`

### Task 2.6: Web Frontend — SP Showcase Portal

**Files:**
- Create: `projulous-web/app/dataAccess/showcase/showcaseSp.da.tsx`
- Create: `projulous-web/app/routes/serviceProviders/showcase/spShowcaseList.route.tsx`
- Create: `projulous-web/app/routes/serviceProviders/showcase/spShowcaseForm.route.tsx`
- Create: `projulous-web/app/routes/serviceProviders/showcase/components/PhotoUploadZone.tsx`
- Create: `projulous-web/app/routes/serviceProviders/showcase/components/PhotoThumbnailGrid.tsx`
- Create: `projulous-web/app/routes/serviceProviders/showcase/components/TagInput.tsx`
- Create: `projulous-web/app/routes/serviceProviders/showcase/components/AiFeedbackPanel.tsx`
- Create: `projulous-web/app/routes/serviceProviders/showcase/components/DeleteShowcaseModal.tsx`
- Modify: `projulous-web/app/routes.ts` (add 3 routes)
- Modify: `projulous-web/app/nav/sidebar.tsx` (add "My Showcase" nav item after "My Offerings")

See `SP_SHOWCASE_SELF_PUBLISHING_PLAN.md` Phases 3.1-3.7 for full details.

- [ ] **Step 1:** Create SP showcase data access class (REST methods for CRUD + photo + AI feedback).
- [ ] **Step 2:** Create showcase list page with stat cards, search, status filter, table, tier gate.
- [ ] **Step 3:** Create showcase editor with two-column layout, photo upload, tag input, AI feedback panel.
- [ ] **Step 4:** Create sub-components (PhotoUploadZone, PhotoThumbnailGrid, TagInput, AiFeedbackPanel, DeleteShowcaseModal).
- [ ] **Step 5:** Add routes to `routes.ts` and sidebar nav item.
- [ ] **Step 6:** Add i18n keys (EN/ES/FR).
- [ ] **Step 7:** Commit: `feat(web): add SP showcase self-publishing portal`

### Task 2.7: Web Frontend — Homepage Wiring

**Files:**
- Modify: `projulous-web/app/routes/home/components/GallerySection.tsx`
- Modify: `projulous-web/app/dataAccess/showcase/showcase.da.tsx`

- [ ] **Step 1:** Update showcase DA GraphQL query to include status, offeringType, photos fields. Add limit arg.
- [ ] **Step 2:** Replace hardcoded `GALLERY_ITEMS` in GallerySection with API call to `getPublishedShowcaseProjects(limit: 4)`. Use primary photo presigned URL as cover image. Graceful fallback if no published posts.
- [ ] **Step 3:** Commit: `feat(web): wire homepage gallery to real showcase data`

### Task 2.8: Permissions Seeding

- [ ] **Step 1:** Seed SHOWCASE_CREATE, SHOWCASE_READ, SHOWCASE_MODIFY, SHOWCASE_DELETE permissions and assign to SERVICE_PROVIDER role using the `/seed-permissions-and-roles` skill or manual SQL.
- [ ] **Step 2:** Commit: `chore(svc): seed showcase permissions`

---

## Batch 3: Project Planner Sprint 7 — Notifications & Polish

Full details in `todo_and_plans/PROJECT_PLANNER_PLAN.md` Sprint 7 section. **Requires shared-dto build.**

### Task 3.1: New Notification Types

**Files:**
- Modify: `projulous-shared-dto-node/shared/enums/notificationType.enum.ts`
- Modify: `projulous-shared-dto-node/shared/configs/notificationCategoryMappings.ts` (or wherever category mappings live)

- [ ] **Step 1:** Add notification types to `NotificationTypeENUM`:
```
PROJECT_PLAN_GENERATED
PROJECT_COLLABORATOR_INVITED
PROJECT_COLLABORATOR_JOINED
PROJECT_NOTE_ADDED
PROJECT_PHASE_COMPLETED
PROJECT_QUOTE_RECEIVED
```

- [ ] **Step 2:** Add category mappings (PROJECT category for all).

- [ ] **Step 3:** Build shared-dto, push to git, install in svc.

- [ ] **Step 4:** Commit: `feat(shared-dto): add project planner notification types`

### Task 3.2: Notification Event Controllers

**Files:**
- Create: `projulous-svc/src/notification/eventControllers/projectPlanner.eventController.ts`
- Modify: `projulous-svc/src/notification/notification.module.ts` (register controller)

**Pattern:** Follow existing event controllers in `projulous-svc/src/notification/eventControllers/`.

- [ ] **Step 1:** Create `ProjectPlannerEventController` handling these events:
- `CUSTOMER_PROJECT_PLAN_GENERATE` → notify project owner "Your project plan is ready"
- `PROJECT_COLLABORATOR_INVITE` → notify invitee "You've been invited to collaborate on {projectName}"
- `PROJECT_COLLABORATOR_ACCEPT` → notify project owner "{name} joined your project"
- `PROJECT_NOTE_CREATE` → notify project owner (if note is from collaborator)
- `PROJECT_PHASE_UPDATE` (status → COMPLETED) → notify project owner "Phase '{phaseName}' is complete"

Each handler creates a notification via `NotificationService.createNotification()` which automatically triggers push via PushNotificationService.

- [ ] **Step 2:** Register in notification module.

- [ ] **Step 3:** Test: create a project plan via PJ → verify notification created + push sent.

- [ ] **Step 4:** Commit: `feat(svc): add project planner notification event controllers`

---

## Batch 4: Mobile Customer Enhancements

All backend APIs exist. No shared-dto or backend changes needed.

### Task 4.1: Maintenance Overview Screen (1.5-2 days)

Full aggregate view of all maintenance reminders across all appliances. Web reference: `projulous-web/app/routes/customers/maintenance/maintenanceOverview.route.tsx`.

**Files:**
- Create: `projulous-mobile/app/maintenance/_layout.tsx`
- Create: `projulous-mobile/app/maintenance/index.tsx`
- Modify: `projulous-mobile/app/(tabs)/settings.tsx` or home screen (add navigation entry)
- Modify: `projulous-mobile/i18n/resources/en/maintenance.json` (add overview keys)
- Modify: `projulous-mobile/i18n/resources/es/maintenance.json`
- Modify: `projulous-mobile/i18n/resources/fr/maintenance.json`

**Existing DA methods** (already in `projulous-mobile/dataAccess/customer/maintenanceReminder.da.ts`):
- `getAllMaintenanceReminders()` — fetches all for customer
- `getOverdueMaintenanceReminders()` — overdue only
- `getUpcomingMaintenanceReminders()` — upcoming only

- [ ] **Step 1:** Create `app/maintenance/_layout.tsx` — Stack layout.

- [ ] **Step 2:** Create `app/maintenance/index.tsx`:
- Summary stat cards at top: Overdue (red), Due Soon (amber), On Track (green) — tappable to filter
- Filter: appliance picker (loads from `CustomerApplianceDA`), status picker
- FlatList of reminder cards: name, appliance name (tappable → appliance detail), next due date, last completed, status badge
- Actions: Mark Complete (navigate to existing maintenance-complete flow), Edit, Delete
- Pull-to-refresh
- Empty state

**Status computation** (match web logic):
- `OVERDUE`: nextDueDate < today
- `DUE_SOON`: nextDueDate within 7 days
- `UPCOMING`: nextDueDate > 7 days
- `NO_SCHEDULE`: no nextDueDate

- [ ] **Step 3:** Add navigation entry — either a "Maintenance" row in settings or a "See All" link from the home screen maintenance widget.

- [ ] **Step 4:** Add i18n keys for EN/ES/FR.

- [ ] **Step 5:** Verify on simulator.

- [ ] **Step 6:** Commit: `feat(mobile): add maintenance overview screen`

### Task 4.2: Ideas Board (2-3 days)

Browse, vote, and submit ideas/feedback. Web reference: `projulous-web/app/routes/helpCenter/ideasBoard.route.tsx`.

**Files:**
- Create: `projulous-mobile/dataAccess/helpCenter/feedback.da.ts`
- Create: `projulous-mobile/app/ideas/_layout.tsx`
- Create: `projulous-mobile/app/ideas/index.tsx`
- Create: `projulous-mobile/app/ideas/[feedbackSubmissionId].tsx`
- Create: `projulous-mobile/app/ideas/submit.tsx`
- Modify: `projulous-mobile/app/(tabs)/settings.tsx` (add navigation)
- Create/Modify: `projulous-mobile/i18n/resources/en/ideas.json` (new namespace)
- Create/Modify: `projulous-mobile/i18n/resources/es/ideas.json`
- Create/Modify: `projulous-mobile/i18n/resources/fr/ideas.json`
- Modify: `projulous-mobile/i18n/index.ts` (register ideas namespace)

**DA methods needed:**
- GraphQL: `getFeedbackSubmissions(skip, take, sort, category?, status?, search?)` — paginated
- GraphQL: `getFeedbackSubmission(feedbackSubmissionId)` — single with votes, comments
- REST POST: `/v1/feedback-submissions` — submit idea
- REST POST: `/v1/feedback-submissions/{id}/vote` — vote
- REST DELETE: `/v1/feedback-submissions/{id}/vote` — unvote

- [ ] **Step 1:** Create feedback data access class.

- [ ] **Step 2:** Create ideas list screen:
- Sort tabs: All, Trending, Most Voted, Newest
- Category filter chips
- Search bar
- FlatList of idea cards: title, description preview, category badge, vote count (with vote button), comment count, status badge
- FAB "Submit Idea"
- Pull-to-refresh, pagination

- [ ] **Step 3:** Create idea detail screen:
- Full description, category, status, timestamps
- Vote button with count
- Comments section
- Submitter info

- [ ] **Step 4:** Create submit idea form:
- Title (required), Description (required), Category picker
- Submit → success → navigate back

- [ ] **Step 5:** Wire navigation in settings: add "Ideas & Feedback" row.

- [ ] **Step 6:** Add i18n namespace + keys for EN/ES/FR. Register in i18n/index.ts.

- [ ] **Step 7:** Commit: `feat(mobile): add ideas board with voting and submission`

### Task 4.3: Customer Billing Screen (1 day)

Simple billing info display. Web reference: `projulous-web/app/routes/customers/billing/billing.route.tsx`.

**Files:**
- Create: `projulous-mobile/app/settings/billing.tsx`
- Modify: `projulous-mobile/app/(tabs)/settings.tsx` (add navigation for customers)
- Modify: `projulous-mobile/i18n/resources/en/settings.json`
- Modify: `projulous-mobile/i18n/resources/es/settings.json`
- Modify: `projulous-mobile/i18n/resources/fr/settings.json`

**Note:** The existing `dataAccess/billing/billing.da.ts` already has `getBillingAccount()` and `getBillingInvoices()` methods. Reuse these.

- [ ] **Step 1:** Create `app/settings/billing.tsx`:
- Billing account card: status badge, tier, period
- Invoice history list: date, amount, status badge, PDF link (opens in WebBrowser)
- Empty state if no billing account

- [ ] **Step 2:** Add "Billing" row to settings for customers (after "My Places" or "Notifications").

- [ ] **Step 3:** Add i18n keys.

- [ ] **Step 4:** Commit: `feat(mobile): add customer billing screen`

### Task 4.4: Project Quotes Tab (1.5-2 days)

Add 5th tab "Quotes" to project detail. Web has it; mobile has 4 tabs.

**Files:**
- Create: `projulous-mobile/components/projects/planner/QuotesTab.tsx`
- Modify: `projulous-mobile/app/project/[projectId].tsx` (add 5th tab)
- Modify: `projulous-mobile/dataAccess/customer/customerProject.da.ts` (add quote queries if missing)
- Modify: `projulous-mobile/i18n/resources/en/projects.json`
- Modify: `projulous-mobile/i18n/resources/es/projects.json`
- Modify: `projulous-mobile/i18n/resources/fr/projects.json`

- [ ] **Step 1:** Check if QuoteRequest data is already loaded in project detail. If not, add a method to the project DA that fetches quote requests linked to the project.

- [ ] **Step 2:** Create `QuotesTab.tsx`:
- List of quote requests grouped by phase (if linked)
- Each quote card: SP name, status badge, amount, date
- Quote detail expandable: message, phase, SP contact info
- Empty state: "No quotes yet"

- [ ] **Step 3:** Add 5th tab to `[projectId].tsx` tab bar. Tab label: "Quotes" with count badge.

- [ ] **Step 4:** Add i18n keys.

- [ ] **Step 5:** Commit: `feat(mobile): add quotes tab to project detail`

---

## Batch 5: Mobile Discovery Features

Backend APIs and web pages exist for all. These must be built in order: Browse → Vendor Landing → SP Detail.

### Task 5.1: Browse Services Screen (1 day)

Grid of all service categories. Web reference: `projulous-web/app/routes/services/browseAll.route.tsx`.

**Files:**
- Create: `projulous-mobile/dataAccess/services/vendorPages.da.ts`
- Create: `projulous-mobile/app/services/_layout.tsx`
- Create: `projulous-mobile/app/services/index.tsx`
- Modify: `projulous-mobile/i18n/resources/en/common.json` (or new namespace)

**DA methods:**
- GraphQL: `getPublishedVendorPages()` — returns all published vendor page configs with slug, displayName, subtitle, offeringType, icon

- [ ] **Step 1:** Create vendor pages data access class.

- [ ] **Step 2:** Create `app/services/index.tsx`:
- Grid (2 columns) of service category cards
- Each card: icon (map offeringType to Lineicons icon), display name, subtitle
- Tap → navigate to `/services/{slug}` (vendor landing)
- Search/filter bar
- Sorted alphabetically by displayName

- [ ] **Step 3:** Add navigation entry — accessible from home screen ("Browse Services" button) or via settings.

- [ ] **Step 4:** Commit: `feat(mobile): add browse services screen`

### Task 5.2: Vendor Landing Pages (2-3 days)

Dynamic pages per service category with provider search. Web reference: `projulous-web/app/routes/services/$vendorType.route.tsx`.

**Files:**
- Create: `projulous-mobile/dataAccess/services/vendorLanding.da.ts`
- Create: `projulous-mobile/app/services/[vendorType].tsx`
- Create: `projulous-mobile/components/services/ProviderCard.tsx`
- Create: `projulous-mobile/components/services/GetQuoteModal.tsx`

**DA methods:**
- GraphQL: `getVendorPageBySlug(slug)` — config with serviceTypes, FAQs, showcase projects
- GraphQL: `getServiceProvidersByOfferingType(offeringType, postalCode?, radius?)` — provider search
- REST POST: `/v1/quote-requests/guest` — submit quote request (already exists in `chat.da.ts`)

- [ ] **Step 1:** Create vendor landing data access class.

- [ ] **Step 2:** Create `app/services/[vendorType].tsx`:
- Hero section with service name + stat badges (provider count)
- Postal code search input (with geolocation option)
- Provider result cards (ProviderCard component)
- Service type filter chips
- FAQ accordion section
- "Get Quote" button → GetQuoteModal

- [ ] **Step 3:** Create `ProviderCard.tsx`:
- Provider initials avatar (colored circle)
- Name, rating stars, location
- Verified/certified badges
- Offerings list (chips)
- "View Profile" and "Get Quote" buttons

- [ ] **Step 4:** Create `GetQuoteModal.tsx`:
- Bottom sheet modal
- Message textarea
- Contact fields (name, email, phone) for guests
- Submit → calls quote request API
- Success state

- [ ] **Step 5:** Add i18n keys.

- [ ] **Step 6:** Commit: `feat(mobile): add vendor landing pages with provider search`

### Task 5.3: SP Detail Page (1.5-2 days)

Standalone SP profile page. Web reference: `projulous-web/app/routes/services/serviceProviderDetail.route.tsx`.

**Files:**
- Create: `projulous-mobile/dataAccess/services/serviceProviderDetail.da.ts`
- Create: `projulous-mobile/app/services/provider/[serviceProviderId].tsx`

**DA methods:**
- GraphQL: `getServiceProviderPublicProfile(serviceProviderId)` — full profile with offerings, reviews summary
- GraphQL: `getSpReviewsForProvider(serviceProviderId, skip, take)` — paginated reviews
- REST POST/DELETE: `/v1/customers/{customerId}/saved-service-providers/{spId}` — save/unsave

- [ ] **Step 1:** Create SP detail data access class.

- [ ] **Step 2:** Create `app/services/provider/[serviceProviderId].tsx`:
- ScrollView layout
- Header: name, verified/certified badges, star rating, review count
- Location section: city, state
- About section: description
- Offerings list: cards with type, radius
- Reviews section: summary stats + paginated review list
- Contact info: email, phone, website
- Action buttons: "Get Quote" (GetQuoteModal), "Save" (heart icon toggle)
- "Write Review" button for customers who have worked with SP

- [ ] **Step 3:** Add navigation from ProviderCard (Task 5.2) "View Profile" button.

- [ ] **Step 4:** Commit: `feat(mobile): add service provider detail page`

---

## Verification Checklist

After all batches complete:

### Batch 1
- [ ] Settings → Billing → SP billing screen loads with account status and invoices
- [ ] Settings → My Offerings → offerings list loads, create/edit/delete works
- [ ] i18n works in all 3 languages for offerings

### Batch 2
- [ ] SP Showcase: Login as PRO SP → create draft → upload photos → set primary → save → publish
- [ ] SP Showcase: Login as FREE SP → cannot create (ForbiddenException)
- [ ] SP Showcase: Click "Ask PJ" → structured AI feedback returns
- [ ] Homepage: GallerySection shows real published posts
- [ ] Draft isolation: drafts do NOT appear on homepage or /projects

### Batch 3
- [ ] Create project via PJ → notification created for plan generation
- [ ] Collaborator accepts invite → project owner gets notification
- [ ] Phase marked complete → project owner gets notification

### Batch 4
- [ ] Maintenance overview: stat cards show correct counts, filters work
- [ ] Ideas board: browse, vote, submit, view detail all work
- [ ] Customer billing: shows account info and invoices
- [ ] Project quotes tab: shows linked quote requests

### Batch 5
- [ ] Browse services: grid of categories loads
- [ ] Vendor landing: search by postal code returns providers
- [ ] SP detail: full profile with reviews, save/unsave works
- [ ] Navigation flow: Browse → Vendor Page → Provider Card → SP Detail works end-to-end

### Cross-Cutting
- [ ] All new screens support dark mode
- [ ] All i18n keys present in EN/ES/FR
- [ ] Pull-to-refresh on all list screens
- [ ] `npm run lint` passes in projulous-mobile
- [ ] `npx expo start` shows no TypeScript errors
- [ ] Backend health check: `GET http://localhost:8123/v1/healthCheck` → 200

---

## Migration Reminders

**Batch 2 (SP Showcase):** After shared-dto Phase 1:
1. Build & push `projulous-shared-dto-node` to git
2. `npm install projulous-shared-dto-node` in projulous-svc
3. `npm run migration:generate -- src/migrations/AddShowcaseProjectStatusAndPhotos`
4. Review SQL, add data migration for existing rows
5. Commit migration file

**Batch 3 (Planner Sprint 7):** After adding notification types:
1. Build & push `projulous-shared-dto-node`
2. `npm install projulous-shared-dto-node` in projulous-svc
3. May need migration if NotificationTypeENUM is a PG enum type — check if new values need `ALTER TYPE`

**Batch 2 Permissions:** Run showcase permissions seed SQL or use `/seed-permissions-and-roles` skill.

---

## Execution Order Summary

| Order | Task | Effort | Dependencies |
|-------|------|--------|-------------|
| 1 | Task 1.1: Wire SP Billing | 1h | None |
| 2 | Task 1.2: SP Offerings CRUD | 2-3d | None |
| 3 | Task 2.1: Showcase shared-dto | 2h | None |
| 4 | Task 2.2: Showcase entity registration + migration | 1h | 2.1 |
| 5 | Task 2.3: Showcase photo service | 3-4h | 2.2 |
| 6 | Task 2.4: Showcase SP service + controller | 4-6h | 2.2 |
| 7 | Task 2.5: Showcase AI feedback | 2-3h | 2.2 |
| 8 | Task 2.6: Showcase web frontend | 6-8h | 2.3, 2.4, 2.5 |
| 9 | Task 2.7: Homepage wiring | 2-3h | 2.4 |
| 10 | Task 2.8: Showcase permissions seed | 30m | 2.2 |
| 11 | Task 3.1: Planner notification types | 1-2h | None (coordinate shared-dto with 2.1) |
| 12 | Task 3.2: Planner event controllers | 3-4h | 3.1 |
| 13 | Task 4.1: Maintenance Overview | 1.5-2d | None |
| 14 | Task 4.2: Ideas Board | 2-3d | None |
| 15 | Task 4.3: Customer Billing | 1d | None |
| 16 | Task 4.4: Project Quotes Tab | 1.5-2d | None |
| 17 | Task 5.1: Browse Services | 1d | None |
| 18 | Task 5.2: Vendor Landing Pages | 2-3d | 5.1 |
| 19 | Task 5.3: SP Detail Page | 1.5-2d | 5.2 |

**Total estimated effort: ~18-24 days**
