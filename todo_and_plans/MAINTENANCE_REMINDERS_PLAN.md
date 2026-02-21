# Maintenance Reminders Feature Plan

**Status:** V1 Implementation Complete (Phases 1-3, 5-8)
**Created:** 2026-02-18
**Completed:** 2026-02-18
**Team:** Technical Architect, UX Designer, Backend PO, Frontend PO

---

## 1. Feature Overview

Allow users to create recurring maintenance reminders for their appliances. Each appliance can have 0..N reminders (e.g., "Replace HVAC Filter every 3 months", "Annual Water Heater Flush"). Users receive notifications before due dates and when overdue, can mark maintenance complete with notes, and the cycle restarts automatically.

### Key Requirements
- Multiple maintenance reminders per appliance
- Configurable frequency: every X days, weeks, months, or years (reuses existing TimeScaleENUM)
- DB-backed MaintenanceTemplate entity for admin-managed defaults per appliance type (global, configurable without code deploy)
- User can override frequency or create custom reminders
- Service provider linking: FK to SP entity + free-text fallback (AI-powered SP search deferred to V2)
- Notifications: advance notice (configurable days before) + overdue
- Mark complete with notes/cost, cycle restarts
- Separate MaintenanceLog entity for completion records; unified timeline in UI merging service history + maintenance logs
- Cross-appliance dashboard view
- Web + mobile in parallel

---

## 2. Architecture Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Entities** | 3 new: `MaintenanceReminder` + `MaintenanceLog` + `MaintenanceTemplate` | Reminder holds recurrence config; Log tracks each completion (separation of concerns); Template enables admin-managed defaults without code deploys. |
| **Templates** | DB-backed `MaintenanceTemplate` entity (admin-managed) | User needs to add maintenance types over time via config, not code releases. Admin CRUD endpoints required. |
| **Frequency** | `frequencyValue: int` + `frequencyUnit: TimeScaleENUM` (DAY/WEEK/MONTH/YEAR) | Reuses existing enum. Supports "every 90 days", "every 2 weeks", "every 6 months", "every 2 years". |
| **Completion flow** | Creates `MaintenanceLog` + advances `nextDueDate` + resets notification tracking. | Separate log entity for clean data model. UI merges service history + maintenance logs into unified timeline. |
| **SP linking** | `serviceProviderId` FK (nullable) + `serviceProviderNotes` text fallback | FK for linking existing SPs. AI-powered SP search deferred to V2. |
| **Notifications** | 5 types: ADVANCE, DUE, OVERDUE_7, OVERDUE_30, COMPLETED. Mapped to `APPLIANCES` category. | Granular enough for good UX. No new notification category needed. |
| **CRON** | Daily at 10 AM UTC, `ENABLE_CRON` guard, per-record error handling | Proven pattern from `ProjectFollowUpCronService`. |
| **Module** | All in existing `CustomerModule` | Tightly coupled with appliances. No new module. |
| **Status** | Computed (not stored): UPCOMING, DUE_SOON, OVERDUE, NO_SCHEDULE | Derived from `nextDueDate` + `notifyDaysBefore` at query time. |
| **Unified Timeline** | UI merges `CustomerApplianceService` + `MaintenanceLog` into single "Service & Maintenance History" | Separate DB tables but combined in the UI for a complete appliance history view. |
| **remindersSent field** | `@Column()` only, NO `@Field()` decorator | GraphQL can't auto-infer `Record<string, string>` type. Internal CRON tracking field not needed by frontend. |

---

## 3. Data Model

### 3.1 Entity: `MaintenanceReminder` (table: `MaintenanceReminders`)

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| `maintenanceReminderId` | uuid PK | no | gen_random_uuid() | Primary key |
| `name` | varchar(128) | no | | Task name (e.g., "Filter Change") |
| `description` | text | yes | | Instructions or notes |
| `frequencyValue` | int | no | 1 | Numeric interval (e.g., 3) |
| `frequencyUnit` | enum TimeScaleENUM | no | MONTH | DAY/WEEK/MONTH/YEAR (reuses existing enum) |
| `nextDueDate` | timestamptz | no | | Next due date |
| `lastCompletedDate` | timestamptz | yes | | Most recent completion |
| `notifyDaysBefore` | int | no | 7 | Days before due to send advance notification |
| `notifyWhenOverdue` | boolean | no | true | Whether to send overdue notifications |
| `isEnabled` | boolean | no | true | Pause/resume without deleting |
| `remindersSent` | jsonb | yes | {} | Tracks sent notifications per cycle. Keys: advance, due, overdue7, overdue30. Reset on completion. NOT exposed via GraphQL. |
| `estimatedCost` | numeric(10,2) | yes | | Expected cost for budgeting |
| `serviceProviderNotes` | text | yes | | Free-text SP contact info fallback |
| `customerApplianceId` | uuid FK | no | | -> CustomerAppliances |
| `customerId` | uuid FK | no | | -> Customers |
| `serviceProviderId` | uuid FK | yes | | -> ServiceProviders |
| `maintenanceTemplateId` | uuid FK | yes | | -> MaintenanceTemplates (source template, if created from one) |
| StandardFields | embedded | no | | createdDate, updatedDate, deletedDate, modifiedByUserId |

**Relations:**
- `ManyToOne -> CustomerAppliance` (required)
- `ManyToOne -> Customer` (required)
- `ManyToOne -> ServiceProvider` (optional)
- `ManyToOne -> MaintenanceTemplate` (optional -- tracks which template this reminder was created from)

**Indexes:**
- `customerApplianceId` (FK lookup)
- `customerId` (FK lookup)
- Composite `(isEnabled, nextDueDate)` (CRON query performance)

### 3.2 Entity: `MaintenanceLog` (table: `MaintenanceLogs`)

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `maintenanceLogId` | uuid PK | no | Primary key |
| `completedDate` | timestamptz | no | When maintenance was performed |
| `notes` | text | yes | User notes about this completion |
| `cost` | numeric(10,2) | yes | Actual cost |
| `maintenanceReminderId` | uuid FK | no | -> MaintenanceReminders |
| `customerApplianceId` | uuid FK | no | -> CustomerAppliances (denormalized for efficient appliance-level queries) |
| `customerId` | uuid FK | no | -> Customers |
| `serviceProviderId` | uuid FK | yes | -> ServiceProviders (who performed it) |
| StandardFields | embedded | no | StandardFields |

**Relations:**
- `ManyToOne -> MaintenanceReminder` (required)
- `ManyToOne -> CustomerAppliance` (required -- denormalized for unified timeline queries)
- `ManyToOne -> Customer` (required)
- `ManyToOne -> ServiceProvider` (optional)

### 3.3 Entity: `MaintenanceTemplate` (table: `MaintenanceTemplates`)

DB-backed, admin-managed default maintenance schedules per appliance type. Users see these as suggestions when adding a reminder.

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `maintenanceTemplateId` | uuid PK | no | Primary key |
| `name` | varchar(128) | no | e.g., "Filter Replacement" |
| `description` | text | yes | Default description |
| `applianceType` | enum ApplianceTypeENUM | no | Which appliance type this template applies to |
| `frequencyValue` | int | no | Default frequency value |
| `frequencyUnit` | enum TimeScaleENUM | no | Default frequency unit |
| `notifyDaysBefore` | int | yes | Default notification lead time (default: 7) |
| `sortOrder` | int | no | Display ordering (default: 0) |
| `isActive` | boolean | no | Soft-disable without deleting (default: true) |
| StandardFields | embedded | no | StandardFields |

**No customer/appliance relation** -- these are global system-level templates.

**Seeded data** (30 templates across 22 appliance types):
- HVAC: Filter Replacement (3mo), Annual Inspection (1yr)
- AC: Filter Replacement (3mo), Annual Tune-up (1yr)
- FURNACE: Filter Replacement (3mo), Annual Inspection (1yr)
- WATER_HEATER: Flush & Inspect (1yr)
- WATER_SOFTENER: Salt Check (1mo), Deep Clean (1yr)
- SEPTIC: Tank Pumping (3yr)
- SUMP_PUMP: Test & Inspect (3mo)
- GENERATOR: Test Run (1mo), Oil Change (1yr)
- DISHWASHER: Deep Clean (6mo)
- WASHING_MACHINE: Deep Clean (3mo)
- DRYER: Vent Cleaning (1yr), Lint Trap Deep Clean (3mo)
- REFRIGERATOR: Coil Cleaning (1yr), Water Filter (6mo)
- GARBAGE_DISPOSAL: Deep Clean (3mo)
- DUCTWORK: Professional Cleaning (3yr)
- WELL_PUMP: Water Quality Test (1yr)
- ELECTRICAL_PANEL: Professional Inspection (5yr)
- HEAT_PUMP: Filter Replacement (3mo), Annual Service (1yr)
- POOL_HEATER: Annual Service (1yr)
- POOL_PUMP: Clean & Inspect (6mo)
- POOL_FILTER: Clean/Replace Filter (6mo)
- OVEN: Deep Clean (6mo)
- STOVE: Burner & Surface Clean (3mo)

Admin can add/edit/delete templates at any time without code deployment.

---

## 4. New Enums & Enum Updates

### 4.1 Reuse: `TimeScaleENUM`
**File:** `projulous-shared-dto-node/shared/enums/timeScale.enum.ts` (already exists)
```
DAY = 'DAY'
WEEK = 'WEEK'
MONTH = 'MONTH'
YEAR = 'YEAR'
```
Already exported. Registered for GraphQL in `maintenanceTemplate.entity.ts`.

### 4.2 New: `MaintenanceReminderStatusENUM`
**File:** `projulous-shared-dto-node/shared/enums/maintenanceReminderStatus.enum.ts`
```
UPCOMING = 'UPCOMING'
DUE_SOON = 'DUE_SOON'
OVERDUE = 'OVERDUE'
NO_SCHEDULE = 'NO_SCHEDULE'
```
Computed virtual field, not stored. Browser-safe. Includes `computeReminderStatus()` pure function.

### 4.3 Update: `NotificationTypeENUM` (+5 values)
```
MAINTENANCE_REMINDER_ADVANCE
MAINTENANCE_REMINDER_DUE
MAINTENANCE_OVERDUE_7
MAINTENANCE_OVERDUE_30
MAINTENANCE_COMPLETED
```

### 4.4 Update: `NOTIFICATION_TYPE_TO_CATEGORY` mapping
All 5 new types -> `NotificationCategoryENUM.APPLIANCES`

### 4.5 Update: `PermissionENUM` (+6 values)
```
MAINTENANCE_REMINDER_CREATE
MAINTENANCE_REMINDER_READ
MAINTENANCE_REMINDER_MODIFY
MAINTENANCE_REMINDER_DELETE
MAINTENANCE_TEMPLATE_READ
MAINTENANCE_TEMPLATE_MODIFY
```

### 4.6 Update: `EventTypeENUM` (+7 values)
```
MAINTENANCE_REMINDER_CREATE
MAINTENANCE_REMINDER_UPDATE
MAINTENANCE_REMINDER_DELETE
MAINTENANCE_REMINDER_COMPLETE
MAINTENANCE_TEMPLATE_CREATE
MAINTENANCE_TEMPLATE_UPDATE
MAINTENANCE_TEMPLATE_DELETE
```

---

## 5. API Contract

### 5.1 GraphQL Queries (Reads)

| Query | Args | Returns | Permission |
|-------|------|---------|------------|
| `getMaintenanceReminders` | `customerApplianceId: String!` | `[MaintenanceReminder]` | MAINTENANCE_REMINDER_READ |
| `getMaintenanceReminderById` | `maintenanceReminderId: String!` | `MaintenanceReminder` | MAINTENANCE_REMINDER_READ |
| `getAllMaintenanceReminders` | (from user context) | `[MaintenanceReminder]` | MAINTENANCE_REMINDER_READ |
| `getUpcomingMaintenanceReminders` | (from user context) | `[MaintenanceReminder]` | MAINTENANCE_REMINDER_READ |
| `getOverdueMaintenanceReminders` | (from user context) | `[MaintenanceReminder]` | MAINTENANCE_REMINDER_READ |
| `getMaintenanceLogs` | `maintenanceReminderId: String!` | `[MaintenanceLog]` | MAINTENANCE_REMINDER_READ |
| `getMaintenanceLogsByAppliance` | `customerApplianceId: String!` | `[MaintenanceLog]` | MAINTENANCE_REMINDER_READ |
| `getMaintenanceTemplates` | `applianceType: ApplianceTypeENUM!` | `[MaintenanceTemplate]` | MAINTENANCE_TEMPLATE_READ |
| `getAllMaintenanceTemplates` | (none) | `[MaintenanceTemplate]` | MAINTENANCE_TEMPLATE_READ |

### 5.2 REST Endpoints (Writes)

Base: `/v1/customers/:customerId/customer-appliances/:applianceId/maintenance-reminders`

| Method | Path | Body | Returns | Permission |
|--------|------|------|---------|------------|
| POST | `/` | CreateMaintenanceReminderDTO | MaintenanceReminder | CREATE |
| PATCH | `/:reminderId` | UpdateMaintenanceReminderDTO | boolean | MODIFY |
| DELETE | `/:reminderId` | - | boolean | DELETE |
| POST | `/:reminderId/complete` | CompleteMaintenanceReminderDTO | MaintenanceReminder | MODIFY |
| POST | `/from-templates` | `{ templateIds: string[] }` | MaintenanceReminder[] | CREATE |

Log endpoints at `/v1/customers/:customerId/maintenance-logs`:

| Method | Path | Body | Returns | Permission |
|--------|------|------|---------|------------|
| PATCH | `/:logId` | UpdateMaintenanceLogDTO | boolean | MODIFY |
| DELETE | `/:logId` | - | boolean | DELETE |

### 5.3 DTOs

**CreateMaintenanceReminderDTO:** name (required), description?, frequencyValue (required), frequencyUnit (required, TimeScaleENUM), nextDueDate (required), notifyDaysBefore? (default 7), notifyWhenOverdue? (default true), isEnabled? (default true), estimatedCost?, serviceProviderId?, serviceProviderNotes?, maintenanceTemplateId?

**UpdateMaintenanceReminderDTO:** All fields optional.

**CompleteMaintenanceReminderDTO:** completedDate? (default now), notes?, cost?, serviceProviderId?

**UpdateMaintenanceLogDTO:** completedDate?, notes?, cost?

**CreateMaintenanceTemplateDTO:** name (required), description?, applianceType (required), frequencyValue (required), frequencyUnit (required), notifyDaysBefore?, sortOrder?

**UpdateMaintenanceTemplateDTO:** All fields optional.

**CreateFromTemplatesDTO:** templateIds (required, string[])

### 5.4 Admin REST Endpoints (Template Management)

Base: `/v1/admin/maintenance-templates`

| Method | Path | Body | Returns | Permission |
|--------|------|------|---------|------------|
| POST | `/` | CreateMaintenanceTemplateDTO | MaintenanceTemplate | MAINTENANCE_TEMPLATE_MODIFY |
| PATCH | `/:templateId` | UpdateMaintenanceTemplateDTO | boolean | MAINTENANCE_TEMPLATE_MODIFY |
| DELETE | `/:templateId` | - | boolean | MAINTENANCE_TEMPLATE_MODIFY |

### 5.5 AI-Powered SP Search Endpoint — DEFERRED TO V2

| Method | Path | Body | Returns | Permission |
|--------|------|------|---------|------------|
| POST | `/v1/customers/:customerId/service-provider-search` | `{ query: string, location?: string }` | `{ results: SPSearchResult[] }` | MAINTENANCE_REMINDER_CREATE |
| POST | `/v1/customers/:customerId/service-provider-search/add` | `{ searchResult: SPSearchResult }` | ServiceProvider | MAINTENANCE_REMINDER_CREATE |

The AI SP search uses existing ProjulousAI infrastructure (Gemini) with web search tools to find service providers by name/type/location, return structured results, and allow adding selected providers to the database.

---

## 6. Service Layer

### 6.1 MaintenanceReminderService
**File:** `projulous-svc/src/customer/services/maintenanceReminder.service.ts`

Methods:
- `getMaintenanceReminders(user, customerApplianceId)` - scoped by customer
- `getMaintenanceReminder(user, maintenanceReminderId)` - single with auth check
- `getAllRemindersForCustomer(user)` - all active for dashboard
- `getUpcomingReminders(user)` - active, due within 30 days
- `getOverdueReminders(user)` - active, past due
- `createMaintenanceReminder(user, dto)` - validate, emit event
- `updateMaintenanceReminder(user, id, dto)` - partial update, emit event
- `deleteMaintenanceReminder(user, id)` - soft delete, emit event
- `completeMaintenanceReminder(user, id, dto)` - **KEY METHOD** (see below)
- `createFromTemplates(user, applianceId, templateKeys)` - bulk create

**Completion Flow:**
1. Fetch reminder, verify auth
2. Set `lastCompletedDate` = dto.completedDate ?? now()
3. Calculate new `nextDueDate` using Luxon: `DateTime.plus({ [unit]: interval })`
4. Reset `remindersSent` = {}
5. Save reminder
6. Create `MaintenanceLog` record (completedDate, notes, cost, serviceProviderId)
7. Emit `MAINTENANCE_REMINDER_COMPLETE` event
8. Return updated reminder

### 6.2 MaintenanceLogService
**File:** `projulous-svc/src/customer/services/maintenanceLog.service.ts`

Methods: `getMaintenanceLogs(user, reminderId)`, `getMaintenanceLogsByAppliance(user, applianceId)`, `updateMaintenanceLog(user, logId, dto)`, `deleteMaintenanceLog(user, logId)`

### 6.2b MaintenanceTemplateService
**File:** `projulous-svc/src/customer/services/maintenanceTemplate.service.ts`

Methods:
- `getMaintenanceTemplates(user, applianceType)` - read templates for a given appliance type (active only)
- `getAllMaintenanceTemplates(user)` - all templates (admin view)
- `createMaintenanceTemplate(user, dto)` - admin only
- `updateMaintenanceTemplate(user, templateId, dto)` - admin only
- `deleteMaintenanceTemplate(user, templateId)` - admin only, soft delete

### 6.3 MaintenanceReminderCronService
**File:** `projulous-svc/src/customer/services/maintenanceReminderCron.service.ts`

- `@Cron('0 10 * * *')` daily at 10 AM UTC
- `ENABLE_CRON` guard
- Processes 4 reminder windows:
  1. **Advance**: nextDueDate within notifyDaysBefore days AND remindersSent.advance IS NULL
  2. **Due**: nextDueDate is today AND remindersSent.due IS NULL
  3. **Overdue 7**: 7+ days past due AND notifyWhenOverdue=true AND remindersSent.overdue7 IS NULL
  4. **Overdue 30**: 30+ days past due AND notifyWhenOverdue=true AND remindersSent.overdue30 IS NULL
- For each: look up user's preferredLanguage, send i18n notification, update remindersSent jsonb
- Per-record error handling (one failure doesn't stop others)
- Deep link: `/customers/appliances/${customerApplianceId}`

### 6.4 i18n Messages
**File:** `projulous-svc/src/customer/messages/maintenanceReminderMessages.ts`

EN/ES/FR messages for advance, due, overdue7, overdue30, completed notifications. Functions take `(applianceName, taskName)` for personalization.

---

## 7. UX/UI Design Summary

### 7.1 Appliance Detail Page - "Maintenance Schedule" Section

**Placement:** Between "Details" and "Service & Maintenance History" sections.

**Reminder Cards:** Each shows name, status badge (green "On Track" / amber "Due Soon" / red "Overdue"), frequency badge, next due date, last completed date, estimated cost. Actions: Complete (checkmark), Edit (pencil), Delete (trash).

**Empty State:** Dashed border + CalendarClock icon + "Add your first reminder" CTA.

### 7.1b Unified Service & Maintenance Timeline

The existing "Service History" section on the appliance detail page has been expanded to merge both `CustomerApplianceService` records AND `MaintenanceLog` entries into a single chronological timeline. This gives users a complete view of all work done on the appliance.

**Timeline entries show:**
- **Service Record:** date, type badge ("Service" - blue/indigo), technician, cost, notes
- **Maintenance Log:** date, type badge ("Maintenance" - green), linked reminder name, cost, notes, SP if any

Both are sorted by date (newest first) in a single list.

### 7.2 Add/Edit Reminder Form
- **Web:** Dialog modal (size="xl"), 2-column grid
- **Mobile:** Pushed screen at `/appliance/maintenance-reminder-form`
- Template suggestions shown as chips when creating (fetched from DB MaintenanceTemplate for the appliance type, pre-fill form on click)
- Fields: name, frequency value, frequency unit, description, next due date, estimated cost, notification toggles (notifyDaysBefore, notifyWhenOverdue), service provider notes, isEnabled toggle

### 7.3 Complete Maintenance Form
- **Web:** Dialog modal (size="md")
- **Mobile:** Pushed screen at `/appliance/maintenance-complete`
- Fields: completion date (default today), notes, cost
- On submit: cycle restarts, card updates to "On Track"

### 7.4 Maintenance Overview Dashboard
- **Web:** New route `/customers/maintenance` + sidebar nav item (CalendarClock icon)
  - Summary cards: Overdue (red), Due Soon (amber), On Track (green) counts (clickable filters)
  - Filter bar: by appliance, by status
  - Full list of reminders across all appliances
- **Mobile:** "Upcoming Maintenance" widget on home screen (top 3 items)
  - Shows status badges, appliance name, due date
  - "See All" navigates to dedicated list screen

### 7.5 Notification UX
- Push + in-app notifications using existing infrastructure
- Deep link to appliance detail page
- Notification preferences: mapped to APPLIANCES category (5 individual toggles for maintenance types)

---

## 8. File Changes Summary

### 8.1 projulous-shared-dto-node

**New files (3):**
- `customer/maintenanceReminder.entity.ts` - entity + 4 DTOs + interfaces
- `customer/maintenanceLog.entity.ts` - entity + DTO + interfaces
- `customer/maintenanceTemplate.entity.ts` - entity + 2 DTOs + interfaces + registers TimeScaleENUM for GraphQL
- `shared/enums/maintenanceReminderStatus.enum.ts` - computed status enum + `computeReminderStatus()` (browser-safe)

**Modified files (5):**
- `customer/index.ts` - add exports
- `shared/enums/index.ts` - add export for MaintenanceReminderStatusENUM + computeReminderStatus
- `shared/enums/permission.enum.ts` - add 6 values
- `shared/enums/notificationType.enum.ts` - add 5 values
- `shared/enums/notificationCategory.enum.ts` - add 5 mappings to APPLIANCES

### 8.2 projulous-svc

**New files (11):**
- `src/customer/services/maintenanceReminder.service.ts`
- `src/customer/services/maintenanceLog.service.ts`
- `src/customer/services/maintenanceTemplate.service.ts`
- `src/customer/services/maintenanceReminderCron.service.ts`
- `src/customer/resolvers/maintenanceReminder.resolver.ts`
- `src/customer/resolvers/maintenanceTemplate.resolver.ts`
- `src/customer/controllers/maintenanceReminder.controller.ts` (includes MaintenanceLogController)
- `src/customer/controllers/maintenanceTemplate.controller.ts`
- `src/customer/eventControllers/maintenanceReminder.eventController.ts`
- `src/customer/messages/maintenanceReminderMessages.ts`

**Modified files (3):**
- `src/customer/customer.module.ts` - register entities, services, resolvers, controllers, event controllers
- `src/app.module.ts` - register entities in defaultDBOptions
- `src/shared/events/eventType.enum.ts` - add 7 event types

### 8.3 projulous-web

**New files (6):**
- `app/dataAccess/customer/maintenanceReminder.da.tsx`
- `app/dataAccess/customer/maintenanceLog.da.tsx`
- `app/routes/customers/maintenance/maintenanceOverview.route.tsx`
- `app/routes/customers/appliances/maintenanceScheduleSection.component.tsx`
- `app/routes/customers/appliances/maintenanceReminderFormModal.component.tsx`
- `app/routes/customers/appliances/completeMaintenanceModal.component.tsx`

**Modified files (6):**
- `app/routes/customers/appliances/appliance.route.tsx` - add MaintenanceScheduleSection
- `app/routes/customers/appliances/serviceHistorySection.component.tsx` - unified timeline (merge service records + maintenance logs)
- `app/routes.ts` - add `/customers/maintenance` route
- `app/nav/sidebar.tsx` - add Maintenance nav item with CalendarClock icon
- `public/translations/en.json` - add maintenance keys
- `public/translations/es.json` and `fr.json` - add translated maintenance keys

### 8.4 projulous-mobile

**New files (7):**
- `dataAccess/customer/maintenanceReminder.da.ts`
- `dataAccess/customer/maintenanceLog.da.ts`
- `app/appliance/maintenance-reminder-form.tsx`
- `app/appliance/maintenance-complete.tsx`
- `i18n/resources/en/maintenance.json`
- `i18n/resources/es/maintenance.json`
- `i18n/resources/fr/maintenance.json`

**Modified files (4):**
- `app/appliance/[applianceId].tsx` - add maintenance schedule section + unified timeline
- `app/(tabs)/index.tsx` - add "Upcoming Maintenance" home screen widget
- `i18n/resources/index.ts` - register maintenance namespace
- `app/settings/notifications.tsx` - add 5 maintenance notification types to local enum + APPLIANCES category mapping

---

## 9. Implementation Phases

### Phase 1: Shared DTO (Entity Developer) -- COMPLETE
1. Created `MaintenanceReminderStatusENUM` enum + `computeReminderStatus()` (browser-safe)
2. Updated `NotificationTypeENUM` (+5), `NotificationCategoryENUM` mappings (+5), `PermissionENUM` (+6)
3. Created `MaintenanceReminder` entity + 4 DTOs (uses existing TimeScaleENUM for frequencyUnit)
4. Created `MaintenanceLog` entity + DTO
5. Created `MaintenanceTemplate` entity + 2 DTOs (registers TimeScaleENUM for GraphQL)
6. Updated index files
7. Built and pushed to git

**Implementation note:** `remindersSent` field uses `@Column()` only (no `@Field()` decorator) because GraphQL can't auto-infer `Record<string, string>` type. Internal CRON tracking field.

### Phase 2: Backend Services (Service Developer) -- COMPLETE
1. Pulled `projulous-shared-dto-node` in projulous-svc
2. Added event types to `EventTypeENUM` (+7)
3. Created `MaintenanceReminderService` (CRUD + complete + createFromTemplates)
4. Created `MaintenanceLogService` (read + update + delete)
5. Created `MaintenanceTemplateService` (admin CRUD)
6. Created `maintenanceReminderMessages.ts` (EN/ES/FR)
7. Created `MaintenanceReminderCronService`
8. Created `MaintenanceReminderEventController`

### Phase 3: Backend API Layer (GraphQL + REST Developers) -- COMPLETE
1. Created `MaintenanceReminderResolver` (7 GraphQL queries)
2. Created `MaintenanceTemplateResolver` (2 GraphQL queries)
3. Created `MaintenanceReminderController` (5 REST endpoints)
4. Created `MaintenanceLogController` (2 REST endpoints, in same file as reminder controller)
5. Created `MaintenanceTemplateController` (3 admin REST endpoints)

### Phase 4: AI Service Provider Search -- DEFERRED TO V2
Not implemented in V1. The `serviceProviderNotes` free-text field provides a fallback for SP contact info. The `serviceProviderId` FK supports linking existing SPs. AI-powered web search for finding/adding new SPs will be built in V2.

### Phase 5: Module Registration + Migration + Seeding -- COMPLETE
1. Registered all in `CustomerModule` and `app.module.ts`
2. Generated and ran database migration for prod (3 new tables + enum updates)
3. Seeded 6 permissions via `seed-permissions-and-roles` skill
4. Assigned 5 permissions to CUSTOMER role (MAINTENANCE_REMINDER_CREATE/READ/MODIFY/DELETE + MAINTENANCE_TEMPLATE_READ)
5. Seeded 30 MaintenanceTemplate rows across 22 appliance types

### Phase 6: Frontend - Web (Frontend Developer) -- COMPLETE
1. Created data access classes (maintenanceReminder.da.tsx, maintenanceLog.da.tsx)
2. Created MaintenanceScheduleSection component (appliance detail) with status badges, CRUD actions, template chips
3. Modified serviceHistorySection to create unified timeline (merge service records + maintenance logs)
4. Created MaintenanceReminderFormModal (add/edit, template suggestions as chips)
5. Created CompleteMaintenanceModal
6. Created Maintenance Overview page at `/customers/maintenance` with summary cards + filters
7. Added route to routes.ts, Maintenance nav item to sidebar.tsx
8. Added i18n translations (EN/ES/FR)

TypeScript typecheck passes with zero errors.

### Phase 7: Frontend - Mobile (Mobile Developer) -- COMPLETE
1. Created data access classes (maintenanceReminder.da.ts, maintenanceLog.da.ts)
2. Added maintenance schedule section + unified timeline to appliance detail screen
3. Created maintenance reminder form screen with template chips
4. Created complete maintenance screen
5. Added "Upcoming Maintenance" home screen widget (top 3 items with status badges)
6. Created i18n translations (EN/ES/FR) in maintenance namespace
7. Registered maintenance namespace in i18n resources

Expo Router auto-discovers new screens via file-based routing.

### Phase 8: Notification Preferences -- COMPLETE
1. **Web:** No changes needed -- settings page dynamically derives category types from shared-dto `NOTIFICATION_TYPE_TO_CATEGORY` mapping, automatically picking up the 5 new maintenance types
2. **Mobile:** Updated hardcoded local enum copy in `app/settings/notifications.tsx` to add 5 maintenance notification types to `NotificationTypeENUM` and `CATEGORY_TO_TYPES[APPLIANCES]`
3. CRON notification verification: deferred to manual QA testing

### Phase 9: QA & Testing -- PENDING
1. Backend unit tests (services, CRON) - not yet written
2. Web Playwright e2e tests - not yet written
3. Mobile manual testing - not yet done
4. Cross-platform verification - not yet done

---

## 10. Migration Reminder

Migration has been generated and run for prod. Local DB uses `synchronize: true`.

After any future entity changes in shared-dto:
1. Build & push `projulous-shared-dto-node` to git
2. `npm install projulous-shared-dto-node` in projulous-svc
3. `npm run migration:generate -- src/migrations/DescriptiveName`
4. Review generated SQL
5. Commit migration file
6. Auto-runs on deploy via `migrationsRun: true`

---

## 11. Deferred Items

### V2: AI-Powered SP Search (Phase 4 - Deferred)
- `ServiceProviderSearchService` using Gemini + web search
- Search + add REST endpoints
- Frontend SP search UI in reminder form (web + mobile)
- Currently using `serviceProviderNotes` free-text fallback and `serviceProviderId` FK for existing SPs

### V2: SP Integration & Scheduling
- **"Need help?" CTA**: When a reminder is due soon/overdue with no SP linked, show a contextual prompt offering to help find a service provider. Routes to Find Service AI flow or SP search.
- **SP visibility**: Allow linked service providers to see maintenance reminders associated with them (new GraphQL query scoped by SP)
- **SP notifications**: Extend CRON to notify the linked SP when maintenance is coming up (configurable per reminder)
- **Auto-scheduling**: When maintenance is due and an SP is linked, automatically create a scheduling request/appointment between customer and SP (requires scheduling feature integration, SP tier gating)

### V2: Other Enhancements
- **Batch operations**: Complete/snooze multiple reminders at once
- **Calendar integration**: Export maintenance schedule to iCal/Google Calendar
- **Cost tracking dashboard**: Budget vs actual maintenance spend over time
- **Auto-suggest on appliance creation**: When user adds a new appliance, automatically prompt to add reminders from templates
- **Recurring cost projections**: Forecast annual maintenance costs based on active reminders
- **Expandable history on reminder cards**: "View history (N)" toggle to show MaintenanceLog entries inline (currently only in unified timeline)

### V2: Architecture Notes
The V1 data model fully supports all V2 SP features without schema changes:
- `serviceProviderId` FK on `MaintenanceReminder` establishes the SP link
- `serviceProviderId` FK on `MaintenanceLog` tracks who performed each service
- CRON service can be extended to look up SP users and send notifications
- No additional columns or entities needed for SP visibility/notifications

### Deferred QA (Phase 9)
- Backend unit test specs for MaintenanceReminderService, MaintenanceLogService, MaintenanceTemplateService, MaintenanceReminderCronService
- Web Playwright e2e test spec for maintenance reminder CRUD flow
- Mobile manual testing checklist
- CRON end-to-end notification verification

---

## 12. Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| CRON notification timing depends on server timezone | Use UTC consistently (existing pattern) |
| Large number of reminders could slow CRON | Composite index on (isEnabled, nextDueDate); batch processing |
| Frequency edge cases (Feb 28 + 1 month) | Use Luxon DateTime for reliable date math |
| AI SP search depends on Gemini availability | Deferred to V2. Free-text `serviceProviderNotes` field as fallback. |
| Unified timeline query complexity | Two separate queries (service records + maintenance logs) merged and sorted client-side |
| Template seed data maintenance | Admin can add/edit templates via API; initial seed covers 22 appliance types |
| Mobile notification preferences uses hardcoded enum copy | Updated to include maintenance types; consider refactoring to dynamic approach in V2 |
