# Projulous Scheduling Feature - Master Plan

## Executive Summary

The Scheduling Feature enables homeowners to discover available times on service provider calendars and book services directly through Projulous. The system integrates PJ (the AI assistant) for conversational scheduling, supports multi-member team scheduling, accounts for travel time between appointments, and provides service providers with comprehensive calendar management, booking workflows, and business analytics.

This plan covers architecture, data model, backend APIs, frontend UX, PJ AI integration, and a phased implementation roadmap.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Data Model & Entities](#2-data-model--entities)
3. [Enums & Status Machines](#3-enums--status-machines)
4. [Backend API Design](#4-backend-api-design)
5. [Availability Engine](#5-availability-engine)
6. [PJ AI Integration](#6-pj-ai-integration)
7. [Frontend Pages & UX](#7-frontend-pages--ux)
8. [Team Scheduling](#8-team-scheduling)
9. [Notifications & Events](#9-notifications--events)
10. [Reporting & Analytics](#10-reporting--analytics)
11. [Calendar Sync Strategy](#11-calendar-sync-strategy)
12. [Permissions](#12-permissions)
13. [Phased Implementation Roadmap](#13-phased-implementation-roadmap)
14. [Exceptional Feature Ideas](#14-exceptional-feature-ideas)
15. [Open Questions & Decisions](#15-open-questions--decisions)

---

## 1. Architecture Overview

### High-Level Data Flow

```
Customer (web/mobile)          PJ AI              Service Provider (web/mobile)
        |                        |                         |
        |-- "I need a plumber    |                         |
        |   Tuesday afternoon"-->|                         |
        |                        |-- checks availability ->|
        |                        |   engine                |
        |<-- "John's Plumbing    |                         |
        |   has 2-4pm open" ----|                         |
        |                        |                         |
        |-- "Book 2pm" -------->|                         |
        |                        |-- create booking ------>|
        |                        |                         |-- notification
        |<-- confirmation -------|                         |<- "New booking!"
```

### Module Architecture (Backend)

```
ScheduleModule (existing - extend)
  ├── ScheduleEntry (existing entity - extend)
  └── ScheduleEntryService (existing - extend)

AvailabilityModule (NEW)
  ├── BusinessHoursService
  ├── TimeOffService
  └── AvailabilityEngineService (core calculation)

BookingModule (NEW)
  ├── BookingService
  ├── BookingController (REST - writes)
  ├── BookingResolver (GraphQL - reads)
  └── BookingEventController

OfferingConfigModule (extends ServiceProviderModule)
  └── OfferingConfigService (duration, pricing, team requirements)

ReportingModule (NEW)
  └── ScheduleReportingService
```

### Integration Points

| System | Integration |
|--------|-------------|
| **ProjulousAI** | New `BookingAssistantService` in ProjulousAI module; PJ uses availability engine to suggest times |
| **Conversations** | New `ConversationTypeENUM.BOOKING` for booking-specific conversations |
| **Events** | New event types for booking lifecycle (created, confirmed, cancelled, completed) |
| **Notifications** | Push/email notifications for booking confirmations, reminders, cancellations |
| **CustomerProject** | Bookings link to projects; a project can have multiple bookings |
| **Team** | Team members assigned to bookings; availability intersected for multi-member jobs |

---

## 2. Data Model & Entities

### 2.1 New Entities

#### `ServiceProviderBusinessHours` (Table: `ServiceProviderBusinessHours`)

Defines recurring weekly availability for a service provider or team member.

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `businessHoursId` | UUID (PK) | No | Primary key |
| `dayOfWeek` | enum `DayOfWeekENUM` | No | MON, TUE, WED, THU, FRI, SAT, SUN |
| `startTime` | time | No | e.g., 08:00 |
| `endTime` | time | No | e.g., 17:00 |
| `isEnabled` | boolean | No | Whether this day is active (default true) |
| `serviceProviderId` | UUID (FK) | No | Owning service provider |
| `userId` | UUID (FK) | Yes | Specific team member (null = company-wide default) |
| `standardFields` | embedded | No | Audit trail |

**Relations:** ManyToOne ServiceProvider, ManyToOne User (optional)

**Notes:** If a team member has no specific business hours, they inherit the company-wide defaults (where userId IS NULL).

#### `ServiceProviderTimeOff` (Table: `ServiceProviderTimeOffs`)

Blocks out specific date/time ranges (vacations, holidays, breaks).

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `timeOffId` | UUID (PK) | No | Primary key |
| `title` | varchar(256) | No | e.g., "Holiday - Memorial Day" |
| `startDateTime` | timestamp | No | Start of blocked period |
| `endDateTime` | timestamp | No | End of blocked period |
| `allDay` | boolean | No | Full-day block (default false) |
| `isRecurringAnnual` | boolean | No | Repeats every year (default false) |
| `serviceProviderId` | UUID (FK) | No | Owning service provider |
| `userId` | UUID (FK) | Yes | Specific team member (null = company-wide) |
| `standardFields` | embedded | No | Audit trail |

**Relations:** ManyToOne ServiceProvider, ManyToOne User (optional)

#### `OfferingConfiguration` (Table: `OfferingConfigurations`)

Extends ServiceProviderOffering with scheduling-specific metadata.

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `offeringConfigurationId` | UUID (PK) | No | Primary key |
| `estimatedDurationMinutes` | integer | No | Default duration in minutes |
| `minimumDurationMinutes` | integer | Yes | Minimum if variable duration |
| `maximumDurationMinutes` | integer | Yes | Maximum if variable duration |
| `bufferBeforeMinutes` | integer | No | Travel/prep buffer before (default 0) |
| `bufferAfterMinutes` | integer | No | Cleanup buffer after (default 0) |
| `priceType` | enum `PriceTypeENUM` | No | FIXED, HOURLY, ESTIMATE, FREE |
| `priceAmountCents` | integer | Yes | Price in cents (null for ESTIMATE) |
| `requiresOnSite` | boolean | No | Whether this requires traveling to customer (default true) |
| `maxDailyBookings` | integer | Yes | Optional daily booking cap |
| `minTeamMembersRequired` | integer | No | Minimum team size needed (default 1) |
| `allowInstantBooking` | boolean | No | Skip approval, book directly (default false) |
| `advanceBookingDaysMin` | integer | No | Minimum days in advance to book (default 0) |
| `advanceBookingDaysMax` | integer | No | Maximum days out to book (default 90) |
| `cancellationPolicyHours` | integer | No | Hours before start for free cancellation (default 24) |
| `serviceProviderOfferingId` | UUID (FK) | No | Linked offering |
| `serviceProviderId` | UUID (FK) | No | Owning service provider |
| `standardFields` | embedded | No | Audit trail |

**Relations:** OneToOne ServiceProviderOffering, ManyToOne ServiceProvider

**Notes:** This is a separate entity (not columns on ServiceProviderOffering) to keep the shared DTO clean and allow the offering to exist without scheduling config. When scheduling is enabled for an offering, an OfferingConfiguration is created.

#### `Booking` (Table: `Bookings`)

The core booking entity representing a scheduled service appointment.

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `bookingId` | UUID (PK) | No | Primary key |
| `bookingNumber` | varchar(20) | No | Human-readable reference (e.g., "BK-2026-00042") |
| `status` | enum `BookingStatusENUM` | No | Booking lifecycle status |
| `startDateTime` | timestamp | No | Appointment start |
| `endDateTime` | timestamp | No | Appointment end |
| `customerNotes` | text | Yes | Notes from customer |
| `providerNotes` | text | Yes | Internal notes from provider |
| `cancellationReason` | text | Yes | Reason if cancelled |
| `cancelledBy` | enum `BookingCancelledByENUM` | Yes | CUSTOMER, PROVIDER, SYSTEM |
| `completedAt` | timestamp | Yes | When service was marked complete |
| `actualDurationMinutes` | integer | Yes | Actual time spent (for reporting) |
| `totalPriceCents` | integer | Yes | Final price in cents |
| `customerProjectId` | UUID (FK) | Yes | Associated project |
| `serviceProviderId` | UUID (FK) | No | Service provider |
| `serviceProviderOfferingId` | UUID (FK) | No | Specific offering booked |
| `customerId` | UUID (FK) | No | Customer who booked |
| `userId` | UUID (FK) | No | User who booked |
| `customerPlaceId` | UUID (FK) | Yes | Service location |
| `conversationId` | UUID (FK) | Yes | Conversation where booking originated |
| `scheduleEntryId` | UUID (FK) | Yes | Linked schedule entry |
| `standardFields` | embedded | No | Audit trail |

**Relations:** ManyToOne for all FKs above. OneToMany BookingTeamAssignment.

#### `BookingTeamAssignment` (Table: `BookingTeamAssignments`)

Assigns specific team members to a booking.

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `bookingTeamAssignmentId` | UUID (PK) | No | Primary key |
| `role` | varchar(128) | Yes | Role on this job (e.g., "Lead Technician") |
| `isLead` | boolean | No | Whether this is the lead assignee (default false) |
| `bookingId` | UUID (FK) | No | Parent booking |
| `userId` | UUID (FK) | No | Assigned team member |
| `standardFields` | embedded | No | Audit trail |

**Relations:** ManyToOne Booking, ManyToOne User

#### `BookingRecurrence` (Table: `BookingRecurrences`)

For recurring service appointments (weekly cleaning, monthly maintenance).

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `bookingRecurrenceId` | UUID (PK) | No | Primary key |
| `recurrencePattern` | enum `RecurrencePatternENUM` | No | WEEKLY, BIWEEKLY, MONTHLY, CUSTOM |
| `recurrenceInterval` | integer | No | Every N weeks/months (default 1) |
| `dayOfWeek` | enum `DayOfWeekENUM` | Yes | For weekly patterns |
| `dayOfMonth` | integer | Yes | For monthly patterns (1-28) |
| `preferredStartTime` | time | No | Preferred time of day |
| `startDate` | date | No | Recurrence series start |
| `endDate` | date | Yes | Recurrence series end (null = ongoing) |
| `maxOccurrences` | integer | Yes | Alternative to endDate |
| `isActive` | boolean | No | Whether recurrence is active (default true) |
| `bookingId` | UUID (FK) | No | Template booking (first in series) |
| `serviceProviderId` | UUID (FK) | No | Service provider |
| `customerId` | UUID (FK) | No | Customer |
| `standardFields` | embedded | No | Audit trail |

**Relations:** ManyToOne Booking (template), ManyToOne ServiceProvider, ManyToOne Customer

### 2.2 Modified Existing Entities

#### `ScheduleEntry` - Add Fields

| New Column | Type | Nullable | Description |
|------------|------|----------|-------------|
| `bookingId` | UUID (FK) | Yes | Link to booking (if this entry came from a booking) |
| `entryType` | enum `ScheduleEntryTypeENUM` | No | MANUAL, BOOKING, TIME_OFF, TRAVEL_BUFFER (default MANUAL) |

**Purpose:** ScheduleEntry remains the universal calendar item. Bookings automatically create ScheduleEntries, but providers can also create manual entries (personal reminders, meetings, etc.).

#### `ServiceProviderOffering` - No Direct Changes

We use a separate `OfferingConfiguration` entity rather than adding columns, keeping the existing offering entity clean. The configuration is optional - offerings without an OfferingConfiguration simply aren't bookable through the scheduling system.

#### `CustomerProject` - No Direct Changes

Bookings reference CustomerProject via `customerProjectId` FK. No changes to CustomerProject needed.

---

## 3. Enums & Status Machines

### New Enums

```typescript
// schedule/enums/bookingStatus.enum.ts
export enum BookingStatusENUM {
  REQUESTED = 'REQUESTED',       // Customer submitted, awaiting provider confirmation
  CONFIRMED = 'CONFIRMED',       // Provider accepted
  IN_PROGRESS = 'IN_PROGRESS',   // Service underway
  COMPLETED = 'COMPLETED',       // Service finished
  CANCELLED = 'CANCELLED',       // Cancelled by either party
  NO_SHOW = 'NO_SHOW',           // Customer didn't show / wasn't available
  RESCHEDULED = 'RESCHEDULED',   // Moved to new time (original booking archived)
}

// schedule/enums/bookingCancelledBy.enum.ts
export enum BookingCancelledByENUM {
  CUSTOMER = 'CUSTOMER',
  PROVIDER = 'PROVIDER',
  SYSTEM = 'SYSTEM',
}

// schedule/enums/priceType.enum.ts
export enum PriceTypeENUM {
  FIXED = 'FIXED',
  HOURLY = 'HOURLY',
  ESTIMATE = 'ESTIMATE',
  FREE = 'FREE',
}

// schedule/enums/dayOfWeek.enum.ts
export enum DayOfWeekENUM {
  MON = 'MON',
  TUE = 'TUE',
  WED = 'WED',
  THU = 'THU',
  FRI = 'FRI',
  SAT = 'SAT',
  SUN = 'SUN',
}

// schedule/enums/recurrencePattern.enum.ts
export enum RecurrencePatternENUM {
  WEEKLY = 'WEEKLY',
  BIWEEKLY = 'BIWEEKLY',
  MONTHLY = 'MONTHLY',
  CUSTOM = 'CUSTOM',
}

// schedule/enums/scheduleEntryType.enum.ts
export enum ScheduleEntryTypeENUM {
  MANUAL = 'MANUAL',
  BOOKING = 'BOOKING',
  TIME_OFF = 'TIME_OFF',
  TRAVEL_BUFFER = 'TRAVEL_BUFFER',
}
```

### Booking Status Machine

```
                              ┌──────────────┐
                              │  REQUESTED   │ ← Customer creates booking
                              └──────┬───────┘
                                     │
                        ┌────────────┼────────────┐
                        │            │            │
                        ▼            ▼            ▼
                 ┌──────────┐ ┌───────────┐ ┌───────────┐
                 │CONFIRMED │ │ CANCELLED │ │RESCHEDULED│
                 └────┬─────┘ └───────────┘ └─────┬─────┘
                      │                           │
                      ▼                     (creates new REQUESTED)
               ┌─────────────┐
               │ IN_PROGRESS │
               └──────┬──────┘
                      │
              ┌───────┼───────┐
              ▼       ▼       ▼
        ┌──────────┐ ┌─────┐ ┌────────┐
        │COMPLETED │ │NO_  │ │CANCELLED│
        └──────────┘ │SHOW │ └────────┘
                     └─────┘
```

**Instant booking flow:** For `allowInstantBooking=true`, status goes directly to CONFIRMED (skipping REQUESTED).

---

## 4. Backend API Design

### 4.1 Availability Module

#### REST Endpoints (Writes)

```
POST   /v1/availability/business-hours          - Create business hours entry
PATCH  /v1/availability/business-hours/:id       - Update business hours
DELETE /v1/availability/business-hours/:id       - Delete business hours
POST   /v1/availability/time-off                 - Create time-off block
PATCH  /v1/availability/time-off/:id             - Update time-off
DELETE /v1/availability/time-off/:id             - Delete time-off
```

#### GraphQL Queries (Reads)

```graphql
type Query {
  # Get business hours for a service provider (or specific team member)
  getBusinessHours(serviceProviderId: String!, userId: String): [ServiceProviderBusinessHours!]!

  # Get time-off entries for a date range
  getTimeOffs(serviceProviderId: String!, startDate: DateTime!, endDate: DateTime!, userId: String): [ServiceProviderTimeOff!]!

  # CORE: Get available time slots for a specific offering
  getAvailableSlots(
    serviceProviderOfferingId: String!
    startDate: DateTime!
    endDate: DateTime!
    customerPlaceId: String          # For travel time calculation
    teamMemberIds: [String!]         # Filter to specific team members
    durationOverrideMinutes: Int     # Override default offering duration
  ): [AvailableSlot!]!
}

type AvailableSlot {
  startDateTime: DateTime!
  endDateTime: DateTime!
  availableTeamMembers: [TeamMemberAvailability!]!
  travelTimeMinutes: Int
  isPreferred: Boolean               # PJ can mark "best" slots
}

type TeamMemberAvailability {
  userId: String!
  userName: String!
  isAvailable: Boolean!
}
```

#### Services

**`BusinessHoursService`**
- `getBusinessHours(user, serviceProviderId, userId?)` - Get business hours
- `createBusinessHours(user, dto)` - Create hours (validate no overlapping times for same day)
- `updateBusinessHours(user, businessHoursId, dto)` - Update
- `deleteBusinessHours(user, businessHoursId)` - Delete
- `getEffectiveHours(serviceProviderId, userId, dayOfWeek)` - Resolve user-specific or fallback to company default

**`TimeOffService`**
- `getTimeOffs(user, serviceProviderId, startDate, endDate, userId?)` - Get blocks in range
- `createTimeOff(user, dto)` - Create block
- `updateTimeOff(user, timeOffId, dto)` - Update
- `deleteTimeOff(user, timeOffId)` - Delete

**`AvailabilityEngineService`** (see Section 5 for algorithm)
- `getAvailableSlots(serviceProviderOfferingId, startDate, endDate, options?)` - Core availability query
- `isSlotAvailable(serviceProviderId, startDateTime, endDateTime, teamMemberIds?)` - Check single slot
- `getNextAvailableSlot(serviceProviderOfferingId, afterDateTime)` - Find next open slot

### 4.2 Booking Module

#### REST Endpoints (Writes)

```
POST   /v1/bookings                    - Create booking (request)
PATCH  /v1/bookings/:bookingId         - Update booking (provider notes, etc.)
POST   /v1/bookings/:bookingId/confirm - Provider confirms booking
POST   /v1/bookings/:bookingId/cancel  - Cancel booking
POST   /v1/bookings/:bookingId/start   - Mark service started
POST   /v1/bookings/:bookingId/complete - Mark service completed
POST   /v1/bookings/:bookingId/reschedule - Reschedule to new time
POST   /v1/bookings/:bookingId/assign-team - Assign team members
```

#### GraphQL Queries (Reads)

```graphql
type Query {
  # Customer: get my bookings
  getMyBookings(status: BookingStatusENUM, startDate: DateTime, endDate: DateTime): [Booking!]!

  # Provider: get bookings for my service provider
  getProviderBookings(
    serviceProviderId: String!
    status: BookingStatusENUM
    startDate: DateTime!
    endDate: DateTime!
    teamMemberId: String
  ): [Booking!]!

  # Single booking detail
  getBooking(bookingId: String!): Booking

  # Provider: pending requests needing action
  getPendingBookingRequests(serviceProviderId: String!): [Booking!]!

  # Calendar view: combined schedule entries + bookings for a date range
  getCalendarView(
    serviceProviderId: String!
    startDate: DateTime!
    endDate: DateTime!
    teamMemberId: String
  ): CalendarView!
}

type CalendarView {
  bookings: [Booking!]!
  manualEntries: [ScheduleEntry!]!
  timeOffs: [ServiceProviderTimeOff!]!
  businessHours: [ServiceProviderBusinessHours!]!
}
```

#### `BookingService`

```typescript
class BookingService {
  // Customer creates a booking request
  createBooking(user, dto: CreateBookingDTO): Promise<Booking>
    // 1. Validate slot is still available (race condition protection with DB lock)
    // 2. Create Booking with status REQUESTED (or CONFIRMED if instant)
    // 3. Create ScheduleEntry linked to booking
    // 4. Create BookingTeamAssignments if team members specified
    // 5. Emit BOOKING_CREATED event
    // 6. Return booking with bookingNumber

  // Provider confirms a booking request
  confirmBooking(user, bookingId): Promise<Booking>
    // 1. Validate booking is in REQUESTED status
    // 2. Re-validate slot availability (in case of conflicts)
    // 3. Update status to CONFIRMED
    // 4. Emit BOOKING_CONFIRMED event (triggers customer notification)

  // Cancel a booking (either party)
  cancelBooking(user, bookingId, dto: CancelBookingDTO): Promise<Booking>
    // 1. Validate booking is cancellable (not COMPLETED/NO_SHOW)
    // 2. Check cancellation policy (warn if within penalty window)
    // 3. Update status to CANCELLED, set cancellationReason + cancelledBy
    // 4. Soft-delete linked ScheduleEntry
    // 5. Emit BOOKING_CANCELLED event

  // Mark service as started (provider)
  startBooking(user, bookingId): Promise<Booking>

  // Mark service as completed (provider)
  completeBooking(user, bookingId, dto: CompleteBookingDTO): Promise<Booking>
    // 1. Update status to COMPLETED
    // 2. Set completedAt, actualDurationMinutes, totalPriceCents
    // 3. Update linked ScheduleEntry status
    // 4. Emit BOOKING_COMPLETED event

  // Reschedule to a new time
  rescheduleBooking(user, bookingId, dto: RescheduleBookingDTO): Promise<Booking>
    // 1. Mark original as RESCHEDULED
    // 2. Create new booking at new time with reference to original
    // 3. Update ScheduleEntry
    // 4. Emit BOOKING_RESCHEDULED event

  // Assign team members
  assignTeamMembers(user, bookingId, dto: AssignTeamDTO): Promise<Booking>
}
```

### 4.3 Offering Configuration

#### REST Endpoints

```
POST   /v1/offering-config                     - Create config for an offering
PATCH  /v1/offering-config/:offeringConfigId    - Update config
DELETE /v1/offering-config/:offeringConfigId    - Delete config (disables scheduling)
```

#### GraphQL Queries

```graphql
type Query {
  getOfferingConfiguration(serviceProviderOfferingId: String!): OfferingConfiguration
  getBookableOfferings(serviceProviderId: String!): [ServiceProviderOffering!]!
}
```

---

## 5. Availability Engine

### Core Algorithm: `getAvailableSlots()`

```
Input: offeringId, dateRange, customerPlaceId?, teamMemberIds?

1. LOAD offering configuration
   → duration, buffer times, team requirements, booking rules

2. LOAD business hours for the service provider (and specific team members if applicable)
   → Map of dayOfWeek → [startTime, endTime] per team member

3. LOAD existing commitments for date range:
   a. Existing bookings (REQUESTED, CONFIRMED, IN_PROGRESS)
   b. Schedule entries (MANUAL type)
   c. Time-off blocks
   d. Travel buffers from adjacent bookings

4. For each day in date range:
   a. Get applicable business hours for that dayOfWeek
   b. Generate candidate slots (start times at configurable intervals, e.g., every 30 min)
   c. For each candidate slot:
      i.   Check against business hours → within working hours?
      ii.  Check against time-off blocks → not blocked?
      iii. Check against existing bookings → no overlap (including buffers)?
      iv.  Check advance booking rules → within min/max days ahead?
      v.   Check daily booking cap → under maxDailyBookings?
      vi.  If requiresOnSite && customerPlaceId:
           - Calculate travel time from previous appointment (see 5.1)
           - Add travel buffer to start time
      vii. If minTeamMembersRequired > 1:
           - Find intersection of available team members (see Section 8)
           - Slot is valid only if enough members are free
      viii. If all checks pass → add to available slots

5. RETURN sorted available slots with team member availability info
```

### 5.1 Travel Time Calculation

**Phase 1 (MVP):** Straight-line distance estimation
- Store service provider's base location (from ServiceProvider postal code or offering centerPointPostalCode)
- Store customer location (from CustomerPlace address/postal code)
- Use Haversine formula for rough distance
- Apply configurable speed assumption (e.g., 30 mph in urban, 45 mph suburban)
- Add flat buffer (e.g., +15 min for parking, setup)

**Phase 2 (Future):** Google Maps Distance Matrix API
- Real driving time estimates
- Cache route calculations (same zip codes)
- Account for time-of-day traffic patterns

### 5.2 Conflict Resolution & Race Conditions

When two customers try to book the same slot simultaneously:

1. Use PostgreSQL `SELECT ... FOR UPDATE` on the booking time window
2. First transaction to commit wins
3. Second transaction gets a "slot no longer available" response
4. Frontend should re-fetch available slots on booking failure

### 5.3 Slot Generation Interval

Configurable per service provider (default: 30-minute increments). A plumber available 8am-5pm with 60-minute appointments would see slots at: 8:00, 8:30, 9:00, 9:30, etc.

---

## 6. PJ AI Integration

### 6.1 Conversational Booking Flow

PJ (the AI assistant) becomes the primary booking interface for customers. The flow integrates with the existing Conversation system.

**New ConversationTypeENUM value:** `BOOKING`

**New fields in Conversation entity (optional):**
- `bookingId` (FK) - links conversation to resulting booking

### 6.2 PJ Booking Conversation Flow

```
User: "I need someone to fix my AC"
  PJ: [Existing FindServiceService identifies HVAC offering type]
  PJ: "I found 3 HVAC providers in your area. Would you like me to check
       availability for Comfort Air Solutions? They have a 4.8 rating."

User: "Yes, check their availability"
  PJ: [Calls AvailabilityEngine.getAvailableSlots()]
  PJ: "Comfort Air Solutions has these openings this week:
       - Tuesday 10:00 AM - 11:30 AM
       - Wednesday 2:00 PM - 3:30 PM
       - Thursday 9:00 AM - 10:30 AM
       Which works best for you?"

User: "Tuesday works"
  PJ: "I'll book you for Tuesday 10:00 AM - 11:30 AM with Comfort Air Solutions
       for AC Repair. The estimated cost is $150/hour.
       Your address on file is 123 Main St. Is that where the service is needed?"

User: "Yes"
  PJ: [Calls BookingService.createBooking()]
  PJ: "Your booking is confirmed! Booking #BK-2026-00042
       - Service: AC Repair
       - Provider: Comfort Air Solutions
       - Date: Tuesday, Feb 10, 10:00 AM - 11:30 AM
       - Location: 123 Main St
       - Estimated Cost: $150/hour
       You'll receive a confirmation notification. Want to add this to a project?"
```

### 6.3 PJ Scheduling Intelligence

PJ should be smarter than a simple time picker:

- **Natural language time parsing:** "next Tuesday afternoon" → Tuesday 12-5pm range
- **Preference learning:** "I usually prefer mornings" → prioritize AM slots
- **Proactive suggestions:** "Your AC unit was installed in 2018 - it might be due for a tune-up. Want me to schedule one?"
- **Conflict detection:** "You have a dentist appointment Tuesday at 2pm. Want me to look at morning slots instead?"
- **Multi-provider comparison:** "Provider A is available Tuesday but costs $150/hr. Provider B is available Wednesday at $120/hr. Which would you prefer?"

### 6.4 Backend Support for PJ

New service in ProjulousAI module:

```typescript
class BookingAssistantService {
  // Parse natural language time preferences into date ranges
  parseTimePreference(input: string): { startDate: Date, endDate: Date, preferences: TimePreference }

  // Get top available slots with scoring
  getSuggestedSlots(userId, offeringType, postalCode, preferences?): SuggestedSlot[]
    // 1. Find matching providers (existing FindServiceService)
    // 2. Get availability for each
    // 3. Score and rank by: rating, price, time match, travel distance
    // 4. Return top 3-5 options

  // Create booking from conversation context
  createBookingFromConversation(conversationId, userId, slotSelection): Booking
}
```

---

## 7. Frontend Pages & UX

### 7.1 Customer-Facing Pages

#### 7.1.1 Booking Flow (PJ-Assisted + Direct)

**Route:** `/customers/book` and `/customers/book/:serviceProviderOfferingId`

**Two entry points:**
1. **Via PJ conversation** (primary) - conversational flow described in Section 6
2. **Direct booking** (from provider profile or offering page) - step wizard:

**Step Wizard Flow:**
```
Step 1: Select Service          Step 2: Pick Time           Step 3: Confirm
┌──────────────────────┐    ┌──────────────────────┐    ┌──────────────────────┐
│ Provider: John's     │    │  ◀ February 2026 ▶   │    │ Booking Summary      │
│ Plumbing             │    │ Mo Tu We Th Fr Sa Su │    │                      │
│                      │    │        1  2  3  4  5 │    │ AC Repair            │
│ Select a service:    │    │  6  7  8  9 10 11 12 │    │ Comfort Air          │
│ ○ AC Repair ($150/hr)│    │ 13 14 15 16 17 18 19 │    │ Tue Feb 10, 10:00 AM │
│ ● Tune-Up ($89 flat) │    │ 20 21 22 23 24 25 26 │    │ Est. 90 min          │
│ ○ Installation (est.)│    │ 27 28                │    │ $89.00 flat          │
│                      │    │                      │    │ 123 Main St          │
│ Location:            │    │ Available times:     │    │                      │
│ [123 Main St ▼]      │    │ ┌──────┐ ┌──────┐   │    │ Notes: (optional)    │
│                      │    │ │10:00 │ │10:30 │   │    │ [________________]   │
│                      │    │ └──────┘ └──────┘   │    │                      │
│       [Next →]       │    │ ┌──────┐ ┌──────┐   │    │ Add to project:      │
│                      │    │ │ 2:00 │ │ 2:30 │   │    │ [Kitchen Remodel ▼]  │
│                      │    │ └──────┘ └──────┘   │    │                      │
│                      │    │      [Next →]       │    │   [Confirm Booking]  │
└──────────────────────┘    └──────────────────────┘    └──────────────────────┘
```

**Data Access:**
- `AvailabilityDA.getAvailableSlots(offeringId, startDate, endDate, placeId)` (GraphQL)
- `BookingDA.createBooking(dto)` (REST)
- `CustomerPlaceDA.getMyPlaces()` (GraphQL - existing)
- `CustomerProjectDA.getMyProjects()` (GraphQL - existing)

#### 7.1.2 Customer Calendar / My Appointments

**Route:** `/customers/appointments`

**Layout:**
```
┌──────────────────────────────────────────────────┐
│ My Appointments                                   │
│ [Upcoming] [Past] [Cancelled]            [+ Book] │
├──────────────────────────────────────────────────┤
│                                                    │
│ Tuesday, February 10                               │
│ ┌────────────────────────────────────────────┐    │
│ │ 🟢 CONFIRMED  10:00 AM - 11:30 AM         │    │
│ │ AC Tune-Up · Comfort Air Solutions          │    │
│ │ 123 Main St · $89.00                        │    │
│ │ [View Details] [Reschedule] [Cancel]        │    │
│ └────────────────────────────────────────────┘    │
│                                                    │
│ Friday, February 13                                │
│ ┌────────────────────────────────────────────┐    │
│ │ 🟡 REQUESTED  2:00 PM - 3:00 PM           │    │
│ │ Plumbing Repair · Quick Fix Plumbing        │    │
│ │ 456 Oak Ave · Est. $150/hr                  │    │
│ │ [View Details] [Cancel Request]             │    │
│ └────────────────────────────────────────────┘    │
│                                                    │
└──────────────────────────────────────────────────┘
```

**Data Access:**
- `BookingDA.getMyBookings(status?, startDate?, endDate?)` (GraphQL)

#### 7.1.3 Booking Detail Page

**Route:** `/customers/appointments/:bookingId`

Shows full booking details, status timeline, provider info, linked project, conversation history. Actions: reschedule, cancel, contact provider.

#### 7.1.4 Reschedule Flow

**Route:** `/customers/appointments/:bookingId/reschedule`

Same time-picker as Step 2 of booking flow, pre-populated with the original offering. On confirm, calls `BookingDA.rescheduleBooking(bookingId, newStartDateTime)`.

### 7.2 Service Provider-Facing Pages

#### 7.2.1 Availability Management

**Route:** `/serviceProviders/availability`

**Layout:**
```
┌──────────────────────────────────────────────────────┐
│ Availability Settings                                 │
├───────────────────────┬──────────────────────────────┤
│                       │                                │
│ Business Hours        │  Time Off & Holidays           │
│ ─────────────         │  ──────────────────            │
│ Mon  [08:00]-[17:00] ✓│  ┌──────────────────────────┐ │
│ Tue  [08:00]-[17:00] ✓│  │ Memorial Day  May 26     │ │
│ Wed  [08:00]-[17:00] ✓│  │ [All Day] [Annual]       │ │
│ Thu  [08:00]-[17:00] ✓│  │ [Edit] [Delete]          │ │
│ Fri  [08:00]-[17:00] ✓│  └──────────────────────────┘ │
│ Sat  [09:00]-[13:00] ✓│  ┌──────────────────────────┐ │
│ Sun  OFF              ✗│  │ Vacation  Mar 15-22      │ │
│                       │  │ [All Day]                │ │
│ Apply to:             │  │ [Edit] [Delete]          │ │
│ ○ Company-wide        │  └──────────────────────────┘ │
│ ● Specific member:    │                                │
│   [Mike T. ▼]         │  [+ Add Time Off]             │
│                       │                                │
│   [Save Hours]        │                                │
└───────────────────────┴──────────────────────────────┘
```

**Data Access:**
- `AvailabilityDA.getBusinessHours(serviceProviderId, userId?)` (GraphQL)
- `AvailabilityDA.createBusinessHours(dto)` / `updateBusinessHours()` / `deleteBusinessHours()` (REST)
- `AvailabilityDA.getTimeOffs(serviceProviderId, startDate, endDate)` (GraphQL)
- `AvailabilityDA.createTimeOff(dto)` / `updateTimeOff()` / `deleteTimeOff()` (REST)

#### 7.2.2 Offering Configuration

**Route:** `/serviceProviders/offerings/:offeringId/scheduling` (or modal from offerings page)

**Layout:**
```
┌────────────────────────────────────────────────┐
│ Scheduling Settings: AC Repair                  │
├────────────────────────────────────────────────┤
│                                                  │
│ Duration                                         │
│ Estimated: [90] minutes                          │
│ Min: [60] min   Max: [180] min                   │
│                                                  │
│ Buffers                                          │
│ Before appointment: [15] min (travel/prep)       │
│ After appointment:  [15] min (cleanup)           │
│                                                  │
│ Pricing                                          │
│ Type: [Hourly ▼]  Rate: [$150.00]                │
│                                                  │
│ Team Requirements                                │
│ Min team members: [1]                            │
│                                                  │
│ Booking Rules                                    │
│ ☑ Allow instant booking (no approval needed)     │
│ Advance booking: [1] to [90] days                │
│ Cancellation window: [24] hours                  │
│ Max daily bookings: [8] (0 = unlimited)          │
│                                                  │
│           [Save Configuration]                   │
└────────────────────────────────────────────────┘
```

#### 7.2.3 Calendar Dashboard

**Route:** `/serviceProviders/calendar`

The primary scheduling hub for service providers.

**Layout:**
```
┌──────────────────────────────────────────────────────────┐
│ Calendar     [Day] [Week] [Month]      ◀ Feb 9-15, 2026 ▶│
│ Team: [All Members ▼]                    [+ Block Time]   │
├──────────────────────────────────────────────────────────┤
│         Mon 9    Tue 10    Wed 11    Thu 12    Fri 13     │
│ 8:00   │         │         │         │         │          │
│ 8:30   │         │         │         │         │          │
│ 9:00   │ ┌─────┐ │         │ ┌─────┐ │         │          │
│ 9:30   │ │AC   │ │         │ │Tune │ │         │          │
│ 10:00  │ │Repair│ │ ┌─────┐ │ │Up   │ │         │          │
│ 10:30  │ │Smith │ │ │Plumb│ │ └─────┘ │         │ ┌─────┐  │
│ 11:00  │ └─────┘ │ │Fix  │ │         │         │ │HVAC │  │
│ 11:30  │         │ │Jones│ │         │ ┌─────┐ │ │Inst.│  │
│ 12:00  │ ░░░░░░░ │ └─────┘ │         │ │Elect│ │ │     │  │
│ 12:30  │ LUNCH   │         │         │ │Work │ │ │     │  │
│ 1:00   │ ░░░░░░░ │         │ ┌─────┐ │ │     │ │ └─────┘  │
│        │         │         │ │AC   │ │ └─────┘ │          │
│ ...    │         │         │ │Tune │ │         │          │
└──────────────────────────────────────────────────────────┘
│ Legend: 🟢 Confirmed  🟡 Requested  🔵 In Progress        │
│         ░░ Time Off   ▨ Travel Buffer                      │
```

**Features:**
- Day/Week/Month toggle views
- Color-coded booking statuses
- Travel buffers shown between appointments
- Click a booking → side panel with details + actions
- Click empty slot → quick-create booking/block time
- Filter by team member
- Drag-to-reschedule (future enhancement)

**Data Access:**
- `BookingDA.getCalendarView(serviceProviderId, startDate, endDate, teamMemberId?)` (GraphQL)

#### 7.2.4 Booking Management (Inbox)

**Route:** `/serviceProviders/bookings`

**Layout:**
```
┌──────────────────────────────────────────────────┐
│ Bookings                                          │
│ [Pending (3)] [Upcoming] [Today] [Past] [All]     │
├──────────────────────────────────────────────────┤
│                                                    │
│ ⚡ Needs Your Action                               │
│ ┌────────────────────────────────────────────┐    │
│ │ 🟡 REQUESTED · BK-2026-00043              │    │
│ │ Plumbing Repair · Jane Smith               │    │
│ │ Fri Feb 13, 2:00 PM · 456 Oak Ave         │    │
│ │ "Kitchen sink is leaking under cabinet"    │    │
│ │                                            │    │
│ │ [✓ Confirm]  [✕ Decline]  [📅 Suggest Alt]│    │
│ └────────────────────────────────────────────┘    │
│                                                    │
│ Upcoming                                           │
│ ┌────────────────────────────────────────────┐    │
│ │ 🟢 CONFIRMED · BK-2026-00042              │    │
│ │ AC Tune-Up · Bob Johnson                    │    │
│ │ Tue Feb 10, 10:00 AM · 123 Main St        │    │
│ │ Assigned: Mike T. (Lead)                    │    │
│ │                                            │    │
│ │ [Start Service] [Reschedule] [Cancel]      │    │
│ └────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────┘
```

#### 7.2.5 Team Scheduling View

**Route:** `/serviceProviders/calendar/team`

Side-by-side calendar columns for each team member, showing who's available when. Useful for assigning team members to bookings.

#### 7.2.6 Reporting Dashboard

**Route:** `/serviceProviders/reports/scheduling`

See Section 10 for details.

### 7.3 Shared Components

| Component | Description |
|-----------|-------------|
| `CalendarGrid` | Reusable day/week/month calendar grid with slot rendering |
| `TimeSlotPicker` | Available time slot selector (used in booking flow) |
| `BookingStatusBadge` | Color-coded status pill (CONFIRMED=green, REQUESTED=yellow, etc.) |
| `BookingCard` | Compact booking summary card (used in lists) |
| `BookingDetailPanel` | Side panel or modal with full booking details |
| `BusinessHoursEditor` | Weekly hours editor with enable/disable per day |
| `TimeOffForm` | Create/edit time-off modal |
| `DurationPicker` | Hours + minutes input for durations |
| `PricingInput` | Price type selector + amount input |

---

## 8. Team Scheduling

### 8.1 How It Works

Service providers with teams need to schedule bookings that require one or more team members. The system needs to:

1. **Know who can do what:** Not all team members can perform all services. Future enhancement: skill-based routing. For MVP, all team members are assumed capable of all offerings.

2. **Find mutual availability:** For multi-member jobs (e.g., 2-person HVAC installation), the availability engine intersects individual calendars.

3. **Assignment flow:**
   - **Auto-assign:** System picks the least-busy available member(s)
   - **Manual assign:** Provider admin selects specific team members
   - **Lead designation:** One team member marked as lead (primary contact)

### 8.2 Availability Intersection Algorithm

```
For a multi-member booking requiring N members:

1. Get all team members for the service provider
2. For each candidate time slot:
   a. Check each member's individual availability
   b. Count how many are free
   c. Slot is valid if available_count >= N
3. Return slots with the specific available members listed
```

### 8.3 Team Calendar View

The team scheduling view shows columns per team member:

```
         Mike T.        Sarah L.       Jim K.
9:00    │ AC Repair  │            │ Plumbing  │
10:00   │ (Smith)    │ Tune-Up    │ (Davis)   │
11:00   │            │ (Jones)    │           │
12:00   │ ░░LUNCH░░  │ ░░LUNCH░░  │ ░░LUNCH░░ │
1:00    │            │ Available  │ Available │
2:00    │ Available  │ HVAC Inst. │ Available │
3:00    │ Available  │ (needs 2)  │           │
```

### 8.4 Future: Skill-Based Routing

Add a `TeamMemberSkill` entity linking team members to OfferingTypes they're qualified for. The availability engine would then filter members by skill before checking availability.

---

## 9. Notifications & Events

### 9.1 New Event Types

Add to `EventTypeENUM` (or equivalent in the event system):

| Event | Trigger | Recipients |
|-------|---------|------------|
| `BOOKING_CREATED` | Customer creates booking | Provider (all admins) |
| `BOOKING_CONFIRMED` | Provider confirms | Customer |
| `BOOKING_CANCELLED` | Either party cancels | Other party |
| `BOOKING_RESCHEDULED` | Either party reschedules | Other party |
| `BOOKING_STARTED` | Provider marks in-progress | Customer |
| `BOOKING_COMPLETED` | Provider marks complete | Customer |
| `BOOKING_REMINDER_24H` | 24 hours before | Both parties |
| `BOOKING_REMINDER_1H` | 1 hour before | Both parties |
| `BOOKING_NO_SHOW` | Provider marks no-show | Customer |
| `BOOKING_TEAM_ASSIGNED` | Team members assigned | Assigned members |

### 9.2 Notification Channels

| Channel | Implementation |
|---------|---------------|
| **In-App** | Existing notification system (NotificationTypeENUM) |
| **Push (Mobile)** | Expo push notifications (existing infrastructure) |
| **Email** | Transactional email (booking confirmation template) |
| **SMS** | Future enhancement |

### 9.3 Reminder System

A scheduled job (cron) runs periodically to:
1. Find bookings with CONFIRMED status where startDateTime is within 24h/1h
2. Check if reminder has already been sent (flag on booking or separate table)
3. Emit reminder events

---

## 10. Reporting & Analytics

### 10.1 Service Provider Dashboard Metrics

**Route:** `/serviceProviders/reports/scheduling`

#### Key Metrics

| Metric | Calculation |
|--------|-------------|
| **Utilization Rate** | (booked hours / available hours) * 100 for a period |
| **Revenue (Period)** | SUM(totalPriceCents) for COMPLETED bookings |
| **Avg. Job Duration** | AVG(actualDurationMinutes) for COMPLETED bookings |
| **Revenue per Hour** | Total revenue / total actual hours worked |
| **Booking Conversion** | CONFIRMED / (CONFIRMED + CANCELLED requests) |
| **Cancellation Rate** | CANCELLED / total bookings |
| **No-Show Rate** | NO_SHOW / total bookings |
| **Avg. Response Time** | Time from REQUESTED → CONFIRMED (or declined) |
| **Repeat Customer Rate** | Customers with 2+ bookings / total unique customers |
| **Top Services** | Bookings grouped by offering, ranked by count/revenue |

#### Dashboard Layout

```
┌──────────────────────────────────────────────────────┐
│ Scheduling Reports       [This Week ▼] [Export CSV]   │
├──────────────────────────────────────────────────────┤
│                                                        │
│  ┌─────────┐  ┌─────────┐  ┌──────────┐  ┌─────────┐ │
│  │ $4,250  │  │  78%    │  │ 2.1 hrs  │  │ $85/hr  │ │
│  │ Revenue │  │ Util.   │  │ Avg Job  │  │ Rev/Hr  │ │
│  │ +12% ▲  │  │ +5% ▲   │  │ -0.2 ▼  │  │ +$3 ▲  │ │
│  └─────────┘  └─────────┘  └──────────┘  └─────────┘ │
│                                                        │
│  Revenue Over Time           Bookings by Service       │
│  ┌─────────────────────┐    ┌────────────────────┐    │
│  │     📈              │    │ AC Repair    ████ 12│    │
│  │   /    \     /      │    │ Tune-Up      ███  8 │    │
│  │  /      \   /       │    │ Installation ██   5 │    │
│  │ /        \_/        │    │ Plumbing     █    3 │    │
│  └─────────────────────┘    └────────────────────┘    │
│                                                        │
│  Team Member Performance                               │
│  ┌─────────────────────────────────────────────┐      │
│  │ Name      │ Jobs │ Hours │ Revenue │ Rating │      │
│  │ Mike T.   │  15  │  32h  │ $2,400  │  4.9   │      │
│  │ Sarah L.  │  12  │  25h  │ $1,850  │  4.7   │      │
│  └─────────────────────────────────────────────┘      │
└──────────────────────────────────────────────────────┘
```

### 10.2 GraphQL Queries for Reporting

```graphql
type Query {
  getSchedulingMetrics(
    serviceProviderId: String!
    startDate: DateTime!
    endDate: DateTime!
  ): SchedulingMetrics!

  getRevenueByOffering(
    serviceProviderId: String!
    startDate: DateTime!
    endDate: DateTime!
  ): [OfferingRevenue!]!

  getTeamMemberPerformance(
    serviceProviderId: String!
    startDate: DateTime!
    endDate: DateTime!
  ): [TeamMemberMetrics!]!

  getRevenueTimeSeries(
    serviceProviderId: String!
    startDate: DateTime!
    endDate: DateTime!
    timeScale: TimeScaleENUM!
  ): [RevenueDataPoint!]!
}
```

---

## 11. Calendar Sync Strategy

### Phase 1 (MVP): No external sync
- Projulous is the source of truth
- Providers manage everything in-app

### Phase 2: One-way export
- iCal (.ics) feed URL per provider → subscribe in Google Calendar, Outlook, Apple Calendar
- Read-only mirror of Projulous bookings in external calendars
- Implementation: `GET /v1/calendar/:serviceProviderId/ical` returns .ics feed

### Phase 3: Two-way sync
- Google Calendar OAuth integration
- Read external events as "busy" blocks in availability engine
- Write Projulous bookings back to Google Calendar
- Conflict detection when external calendar changes

### Phase 4: Deep integration
- Embed Google Calendar in Projulous UI
- Zapier/Make integrations for other calendar apps

---

## 12. Permissions

### New Permission Enums

```typescript
// Add to PermissionENUM:
BOOKING_CREATE = 'BOOKING_CREATE',         // Customer creates booking
BOOKING_READ = 'BOOKING_READ',             // Read booking details
BOOKING_MODIFY = 'BOOKING_MODIFY',         // Update booking (notes, assign team)
BOOKING_DELETE = 'BOOKING_DELETE',          // Cancel/delete booking
BOOKING_CONFIRM = 'BOOKING_CONFIRM',       // Provider confirms/declines

AVAILABILITY_CREATE = 'AVAILABILITY_CREATE', // Set business hours / time off
AVAILABILITY_READ = 'AVAILABILITY_READ',     // View availability
AVAILABILITY_MODIFY = 'AVAILABILITY_MODIFY', // Update availability settings
AVAILABILITY_DELETE = 'AVAILABILITY_DELETE',  // Delete availability entries

OFFERING_CONFIG_CREATE = 'OFFERING_CONFIG_CREATE',  // Configure offering scheduling
OFFERING_CONFIG_READ = 'OFFERING_CONFIG_READ',
OFFERING_CONFIG_MODIFY = 'OFFERING_CONFIG_MODIFY',
OFFERING_CONFIG_DELETE = 'OFFERING_CONFIG_DELETE',

SCHEDULE_REPORT_READ = 'SCHEDULE_REPORT_READ',  // View scheduling reports
```

### Role Assignments

| Permission | Customer | SP Admin | SP Member | Super Admin |
|-----------|----------|----------|-----------|-------------|
| BOOKING_CREATE | Yes | Yes | No | Yes |
| BOOKING_READ | Own only | All for SP | Own only | All |
| BOOKING_MODIFY | Limited | Yes | Limited | Yes |
| BOOKING_CONFIRM | No | Yes | No | Yes |
| AVAILABILITY_* | No | Yes | Own hours | Yes |
| OFFERING_CONFIG_* | No | Yes | No | Yes |
| SCHEDULE_REPORT_READ | No | Yes | No | Yes |

---

## 13. Phased Implementation Roadmap

Each phase is a self-contained deliverable with clear inputs, outputs, acceptance criteria, and dependencies. Phases build on each other but each produces a shippable increment.

---

### PHASE 0: Shared DTO Foundation -- COMPLETE
**Timeline:** Week 0 (pre-work)
**Dependencies:** None
**Owners:** Backend Entity Developer, Technical Architect
**Completed:** 2026-02-09

**Objective:** Create all new entities, enums, DTOs, and permission definitions in projulous-shared-dto-node so that backend and frontend teams can begin Phase 1 in parallel.

**Deliverables:**

| # | Deliverable | Status |
|---|-------------|--------|
| 0.1 | New enums: `BookingStatusENUM`, `BookingCancelledByENUM`, `DayOfWeekENUM`, `PriceTypeENUM`, `ScheduleEntryTypeENUM`, `RecurrencePatternENUM` in `shared/enums/` | [x] |
| 0.2 | Export all new enums from `shared/enums/index.ts` and `shared/index.ts` | [x] |
| 0.3 | New entity: `ServiceProviderBusinessHours` with `DayOfWeekENUM`, time fields, SP + User relations | [x] |
| 0.4 | New entity: `ServiceProviderTimeOff` with date range, allDay, isRecurringAnnual, SP + User relations | [x] |
| 0.5 | New entity: `OfferingConfiguration` with duration, buffers, pricing, booking rules, linked to ServiceProviderOffering | [x] |
| 0.6 | New entity: `Booking` with full field set (bookingNumber, status, dates, pricing, notes, cancellation), all FK relations | [x] |
| 0.7 | New entity: `BookingTeamAssignment` with role, isLead, Booking + User relations | [x] |
| 0.8 | Modify existing `ScheduleEntry`: add `bookingId` (FK, nullable) and `entryType` (`ScheduleEntryTypeENUM`, default MANUAL) | [x] |
| 0.9 | Create/Update DTOs for all new entities with `@ApiProperty`/`@ApiPropertyOptional` annotations | [x] |
| 0.10 | Add new permissions to `PermissionENUM`: BOOKING_*, AVAILABILITY_*, OFFERING_CONFIG_*, SCHEDULE_REPORT_READ | [x] |
| 0.11 | `registerEnumType()` calls for all new GraphQL enums at top of entity files | [x] |
| 0.12 | Build (`npm run buildProd`) passes with zero errors | [x] |

**Acceptance Criteria:** All met.
- `npm run buildProd` succeeds
- All entities follow existing patterns (StandardFields, UUID PKs, Relation<> wrapper, proper decorators)
- All DTOs have proper Swagger annotations
- All new enums registered for GraphQL
- No changes to projulous-svc, projulous-web, or projulous-mobile

**Entities NOT included in Phase 0** (deferred):
- `BookingRecurrence` → Phase 7 (recurring bookings)

---

### PHASE 1: Availability Management
**Timeline:** Weeks 1-3
**Dependencies:** Phase 0 (shared DTOs published)
**Owners:** Backend Service Dev, Backend REST Dev, Backend GraphQL Dev, Frontend Dev

**Objective:** Service providers can configure their business hours and time-off blocks. Offering scheduling configuration (duration, pricing, buffers) is settable. The availability engine can compute open slots for a single provider (no travel time or team logic yet).

**Deliverables:**

*Backend (projulous-svc):*

| # | Deliverable | Status |
|---|-------------|--------|
| 1.1 | `AvailabilityModule` registered in `app.module.ts` with all new entities | [ ] |
| 1.2 | `BusinessHoursService` — CRUD for ServiceProviderBusinessHours (validate no overlapping times per day/user) | [ ] |
| 1.3 | `TimeOffService` — CRUD for ServiceProviderTimeOff | [ ] |
| 1.4 | `OfferingConfigService` — CRUD for OfferingConfiguration (1:1 with ServiceProviderOffering) | [ ] |
| 1.5 | `AvailabilityEngineService.getAvailableSlots()` — core slot calculation for a single offering (business hours - existing bookings - time off) | [ ] |
| 1.6 | REST controllers for business hours, time-off, offering config (POST, PATCH, DELETE) | [ ] |
| 1.7 | GraphQL resolvers: `getBusinessHours`, `getTimeOffs`, `getAvailableSlots`, `getOfferingConfiguration`, `getBookableOfferings` | [ ] |
| 1.8 | Event emission for create/update/delete on all new entities | [ ] |
| 1.9 | Seed new permissions + role assignments via `seed-permissions-and-roles` | [ ] |
| 1.10 | Unit tests for BusinessHoursService, TimeOffService, OfferingConfigService | [ ] |
| 1.11 | Unit tests for AvailabilityEngineService (slot calculation correctness) | [ ] |

*Frontend (projulous-web):*

| # | Deliverable | Status |
|---|-------------|--------|
| 1.12 | `AvailabilityDA` data access class (GraphQL queries + REST mutations) | [ ] |
| 1.13 | `OfferingConfigDA` data access class | [ ] |
| 1.14 | SP route: `/serviceProviders/availability` — business hours weekly editor + time-off management | [ ] |
| 1.15 | SP route or modal: Offering Configuration form (duration, buffers, pricing, booking rules) | [ ] |
| 1.16 | `BusinessHoursEditor` component | [ ] |
| 1.17 | `TimeOffForm` modal component | [ ] |

**Acceptance Criteria:**
- A service provider can set Mon-Sun business hours with start/end times per day
- A service provider can set per-team-member business hour overrides
- A service provider can add/edit/delete time-off blocks (one-time and recurring annual)
- A service provider can configure an offering with duration, buffers, pricing, and booking rules
- `getAvailableSlots()` returns correct open slots for a given offering + date range, respecting business hours, existing schedule entries, and time-off
- All backend tests pass
- Permissions enforced: only SP admins can manage availability

---

### PHASE 2: Booking Flow
**Timeline:** Weeks 4-6
**Dependencies:** Phase 1
**Owners:** Backend Service Dev, Backend REST Dev, Backend GraphQL Dev, Frontend Dev

**Objective:** Customers can browse available times and create bookings. Service providers can confirm, decline, start, complete, and cancel bookings. The core booking lifecycle works end-to-end.

**Deliverables:**

*Backend:*

| # | Deliverable | Status |
|---|-------------|--------|
| 2.1 | `BookingModule` registered in `app.module.ts` | [ ] |
| 2.2 | `BookingService` — full lifecycle: create, confirm, cancel, start, complete, reschedule | [ ] |
| 2.3 | Race condition protection: `SELECT ... FOR UPDATE` on slot validation during booking creation | [ ] |
| 2.4 | Auto-generate `bookingNumber` (format: `BK-YYYY-NNNNN`) via DB sequence | [ ] |
| 2.5 | Booking → ScheduleEntry auto-creation (status sync between the two) | [ ] |
| 2.6 | `BookingController` — REST endpoints for all write operations | [ ] |
| 2.7 | `BookingResolver` — GraphQL queries: `getMyBookings`, `getProviderBookings`, `getBooking`, `getPendingBookingRequests` | [ ] |
| 2.8 | `BookingEventController` — event emission for all booking state transitions | [ ] |
| 2.9 | Support both instant booking and approval-required modes (per OfferingConfiguration) | [ ] |
| 2.10 | Unit + integration tests for BookingService lifecycle | [ ] |

*Frontend:*

| # | Deliverable | Status |
|---|-------------|--------|
| 2.11 | `BookingDA` data access class | [ ] |
| 2.12 | Customer route: `/customers/book/:serviceProviderOfferingId` — 3-step booking wizard (Select Service → Pick Time → Confirm) | [ ] |
| 2.13 | `TimeSlotPicker` component — calendar date selector + grouped time slot buttons | [ ] |
| 2.14 | Booking confirmation view with booking number, status, "Add to Calendar", next steps | [ ] |
| 2.15 | Customer route: `/customers/appointments` — upcoming/past/cancelled booking list | [ ] |
| 2.16 | Customer route: `/customers/appointments/:bookingId` — booking detail page | [ ] |
| 2.17 | Customer: Cancel booking flow (confirmation modal with reason) | [ ] |
| 2.18 | Customer: Reschedule flow (re-use time slot picker, call reschedule endpoint) | [ ] |
| 2.19 | SP route: `/serviceProviders/bookings` — booking inbox with Pending/Upcoming/Today/Past tabs | [ ] |
| 2.20 | SP actions: Confirm, Decline (with reason), Start Service, Complete (with actual duration + price) | [ ] |
| 2.21 | `BookingStatusBadge` component (color + icon + text, colorblind-safe) | [ ] |
| 2.22 | `BookingCard` component for list views | [ ] |

**Acceptance Criteria:**
- Customer can view available slots for a bookable offering and create a booking
- Instant-book offerings go straight to CONFIRMED; approval-required go to REQUESTED
- Provider sees pending requests, can confirm/decline with one click
- Provider can mark bookings as started and completed (with actual duration/price)
- Either party can cancel with reason; reschedule creates new booking
- Booking number is generated and displayed
- ScheduleEntry is auto-created and stays in sync with booking status
- No double-bookings possible (race condition handled)

---

### PHASE 3: Calendar & Team Scheduling
**Timeline:** Weeks 7-9
**Dependencies:** Phase 2
**Owners:** Backend Service Dev, Backend GraphQL Dev, Frontend Dev

**Objective:** Service providers get a visual calendar dashboard. Team scheduling works: assign members to bookings, view team availability side-by-side, and multi-member availability intersection in the engine. Travel time estimation added.

**Deliverables:**

*Backend:*

| # | Deliverable | Status |
|---|-------------|--------|
| 3.1 | `getCalendarView` GraphQL query — returns combined bookings, manual entries, time-off, business hours for a date range | [ ] |
| 3.2 | AvailabilityEngine: team member availability intersection (find slots where N members are free) | [ ] |
| 3.3 | AvailabilityEngine: travel time estimation via Haversine formula + configurable speed | [ ] |
| 3.4 | AvailabilityEngine: travel buffers between adjacent bookings (based on customer location) | [ ] |
| 3.5 | `BookingService.assignTeamMembers()` — assign/reassign team members, validate availability | [ ] |
| 3.6 | Auto-assign algorithm: pick least-busy available member(s) | [ ] |
| 3.7 | Tests for team intersection logic and travel time estimation | [ ] |

*Frontend:*

| # | Deliverable | Status |
|---|-------------|--------|
| 3.8 | `CalendarGrid` shared component — day/week/month views with slot rendering and status colors | [ ] |
| 3.9 | SP route: `/serviceProviders/calendar` — calendar dashboard with view toggle, team member filter, current-time indicator | [ ] |
| 3.10 | Calendar: click booking → slide-in detail panel; click empty slot → quick-add popover | [ ] |
| 3.11 | SP route: `/serviceProviders/calendar/team` — side-by-side team member columns with utilization bars | [ ] |
| 3.12 | Travel buffer visualization on calendar (hatched/striped blocks) | [ ] |
| 3.13 | Team assignment UI: assign members on booking detail; show assigned members on calendar cards | [ ] |
| 3.14 | Mobile: agenda/list view default for calendar, bottom-sheet for booking details | [ ] |

**Acceptance Criteria:**
- Provider can view their schedule in day/week/month calendar views
- Clicking a booking on the calendar shows details in a side panel
- Team member filter shows individual or all-team schedule
- Team view shows side-by-side columns per member with utilization
- `getAvailableSlots()` accounts for travel time between appointments (if customer location provided)
- Multi-member bookings only show slots where enough team members are available
- Team members can be assigned to bookings; auto-assign picks the least-busy

---

### PHASE 4: PJ AI-Assisted Booking
**Timeline:** Weeks 10-12
**Dependencies:** Phase 2 (booking flow must work), Phase 1 (availability engine)
**Owners:** Backend Service Dev, Prompt Engineer, Frontend Dev

**Objective:** PJ can guide customers through the entire booking process conversationally. Natural language time preferences ("next Tuesday afternoon") are understood. PJ suggests the best provider + time combinations.

**Deliverables:**

*Backend:*

| # | Deliverable | Status |
|---|-------------|--------|
| 4.1 | `BookingAssistantService` in ProjulousAI module — orchestrates provider discovery → availability → booking | [ ] |
| 4.2 | Natural language time preference parser: "next week", "Tuesday afternoon", "mornings preferred" → date range + time-of-day filter | [ ] |
| 4.3 | `getSuggestedSlots()` — score and rank slots across providers by: rating, price, time match, travel distance | [ ] |
| 4.4 | `createBookingFromConversation()` — create booking with conversation context linked | [ ] |
| 4.5 | Add `ConversationTypeENUM.BOOKING` to shared DTO | [ ] |
| 4.6 | PJ prompt templates for booking flow steps (provider selection, time selection, confirmation, error handling) | [ ] |
| 4.7 | Integration: FindServiceService → AvailabilityEngine → BookingService pipeline | [ ] |

*Frontend:*

| # | Deliverable | Status |
|---|-------------|--------|
| 4.8 | PJ chat: inline available-slot cards rendered in conversation (clickable to select) | [ ] |
| 4.9 | PJ chat: inline booking confirmation card after booking is created | [ ] |
| 4.10 | PJ chat: booking status update messages in conversation thread | [ ] |
| 4.11 | "Book again" shortcut on past booking cards → starts PJ conversation with context | [ ] |

**Acceptance Criteria:**
- Customer can say "I need a plumber next Tuesday afternoon" and PJ finds providers, shows available slots, and books on confirmation
- PJ handles: no availability ("next available is Thursday"), multiple providers ("Provider A has Tuesday, Provider B has Wednesday"), preference clarification
- Booking created via PJ links to the conversation
- Inline slot cards in chat are interactive (clickable to select)

---

### PHASE 5: Notifications, Reminders & Polish
**Timeline:** Weeks 13-14
**Dependencies:** Phase 2
**Owners:** Backend Service Dev, Frontend Dev, Mobile Dev

**Objective:** Complete notification system for the booking lifecycle. Email confirmations, push reminders, and in-app notification rendering for all booking events.

**Deliverables:**

*Backend:*

| # | Deliverable | Status |
|---|-------------|--------|
| 5.1 | Booking event handlers → notification creation for all event types (see Section 9.1) | [ ] |
| 5.2 | Email templates: booking confirmation, booking confirmed by provider, reminder (24h + 1h), cancellation, reschedule | [ ] |
| 5.3 | Reminder cron job (`@nestjs/schedule`): query upcoming CONFIRMED bookings, emit BOOKING_REMINDER_24H and BOOKING_REMINDER_1H | [ ] |
| 5.4 | Push notification payloads for mobile (Expo push) | [ ] |
| 5.5 | Reminder deduplication (don't send twice for same booking) | [ ] |

*Frontend (web + mobile):*

| # | Deliverable | Status |
|---|-------------|--------|
| 5.6 | Notification center: render booking notification types with booking link | [ ] |
| 5.7 | Email notification preferences: opt-in/out per notification type | [ ] |
| 5.8 | UX polish pass: loading skeletons, empty states, error recovery (per UX_BEST_PRACTICES.md) | [ ] |
| 5.9 | Mobile: push notification deep links to booking detail | [ ] |

**Acceptance Criteria:**
- Customer receives email confirmation when booking is created
- Customer receives email + push when provider confirms
- Both parties receive 24h and 1h reminders
- Cancellation and reschedule trigger notifications to the other party
- In-app notification center shows all booking events with links
- Users can manage notification preferences

---

### PHASE 6: Reporting & Analytics
**Timeline:** Weeks 15-16
**Dependencies:** Phase 2 (needs booking data to report on)
**Owners:** Backend GraphQL Dev, Frontend Dev

**Objective:** Service providers get a reporting dashboard with key scheduling metrics: revenue, utilization, job duration, team performance, and booking conversion.

**Deliverables:**

*Backend:*

| # | Deliverable | Status |
|---|-------------|--------|
| 6.1 | `ScheduleReportingService` — aggregate queries for metrics (see Section 10.1) | [ ] |
| 6.2 | GraphQL: `getSchedulingMetrics`, `getRevenueByOffering`, `getTeamMemberPerformance`, `getRevenueTimeSeries` | [ ] |
| 6.3 | CSV export endpoint: `GET /v1/reports/scheduling/export` | [ ] |

*Frontend:*

| # | Deliverable | Status |
|---|-------------|--------|
| 6.4 | SP route: `/serviceProviders/reports/scheduling` — reporting dashboard | [ ] |
| 6.5 | Summary metric cards: revenue, utilization rate, avg job duration, revenue/hour | [ ] |
| 6.6 | Revenue over time chart (line/bar, filterable by TimeScaleENUM) | [ ] |
| 6.7 | Bookings by service type chart (horizontal bar) | [ ] |
| 6.8 | Team member performance table (jobs, hours, revenue, rating) | [ ] |
| 6.9 | Date range selector + export CSV button | [ ] |

**Acceptance Criteria:**
- Provider dashboard shows accurate metrics for selected date range
- Charts update when date range or time scale changes
- Team performance table shows per-member breakdown
- CSV export downloads correctly formatted data
- Dashboard loads in under 2 seconds for typical data volumes

---

### PHASE 7: Advanced Features (Future)
**Timeline:** Weeks 17+
**Dependencies:** Phases 1-6 complete
**Owners:** TBD per feature

These are independent feature increments that can be prioritized individually:

| # | Feature | Depends On | Complexity |
|---|---------|-----------|------------|
| 7.1 | **Recurring Bookings** — BookingRecurrence entity, series generation, management UI | Phase 2 | High |
| 7.2 | **iCal Feed Export** — `.ics` feed URL per provider for external calendar subscriptions | Phase 3 | Medium |
| 7.3 | **Google Calendar Two-Way Sync** — OAuth integration, read external events as busy blocks | Phase 3 | High |
| 7.4 | **Waitlist & Cancellation Backfill** — join waitlist when full, auto-notify on cancellation | Phase 2 | Medium |
| 7.5 | **Customer Reviews Post-Completion** — rating + review prompt after COMPLETED status | Phase 2 | Low |
| 7.6 | **Deposit/Payment at Booking** — Stripe integration for deposits or full prepayment | Phase 2 + Stripe billing | High |
| 7.7 | **Drag-to-Reschedule** — drag booking cards on calendar to new time | Phase 3 | Medium |
| 7.8 | **Skill-Based Team Routing** — TeamMemberSkill entity, filter by qualification | Phase 3 | Medium |
| 7.9 | **SMS Notifications** — Twilio/SNS integration for text reminders | Phase 5 | Medium |
| 7.10 | **Dynamic Pricing** — peak/off-peak pricing, PJ suggests cheaper times | Phase 4 | Medium |
| 7.11 | **Real-Time Job Tracking** — live status + GPS ETA updates | Phase 2 + Mobile | High |
| 7.12 | **Multi-Day Project Scheduling** — Gantt-style scheduling for multi-day projects | Phase 3 | High |
| 7.13 | **Neighborhood Clustering** — group nearby appointments, suggest efficient routing | Phase 3 | Medium |

---

### Phase Dependency Map

```
Phase 0: Shared DTOs ──────────────────────────────────────────┐
    │                                                           │
    ▼                                                           │
Phase 1: Availability ─────────────────────────┐               │
    │                                           │               │
    ▼                                           ▼               │
Phase 2: Booking Flow ──────────┬──── Phase 4: PJ AI          │
    │                           │         (also needs Ph1)      │
    ▼                           ▼                               │
Phase 3: Calendar & Team   Phase 5: Notifications              │
    │                           │                               │
    ▼                           ▼                               │
Phase 6: Reporting         Phase 7: Advanced                   │
    │                      (independent features)               │
    ▼                                                           │
Phase 7: Advanced ◄─────────────────────────────────────────────┘
```

**Key insight:** Phase 4 (PJ AI) can run in parallel with Phase 3 (Calendar) since they share Phase 2 as a dependency but don't depend on each other. This allows two teams to work simultaneously.

---

## 14. Exceptional Feature Ideas

These go beyond the core requirements to make Projulous scheduling truly exceptional:

### 14.1 Smart Scheduling Suggestions
- PJ proactively suggests maintenance based on appliance age/service history: "Your water heater was installed in 2020. Most manufacturers recommend a flush every 2 years. Want me to schedule one?"
- Seasonal service reminders: "It's October - want to schedule your annual furnace inspection before winter?"

### 14.2 Waitlist & Cancellation Backfill
- When a desired slot is full, customers can join a waitlist
- When a cancellation opens a slot, waitlisted customers get first dibs
- PJ notifies: "Good news! A slot opened up on Tuesday at 2pm. Want me to book it?"

### 14.3 Dynamic Pricing
- Service providers can set peak/off-peak pricing
- Discounts for off-peak booking incentivize filling quiet periods
- PJ can suggest: "Wednesday 2pm is $20 cheaper than Tuesday morning"

### 14.4 Service Package Bundles
- Bundle related services with combined scheduling: "HVAC Spring Tune-Up Package: AC check + filter replacement + duct cleaning"
- Auto-schedule sequential services with appropriate gaps

### 14.5 Customer Preference Learning
- Track preferred times, providers, and service patterns
- PJ remembers: "You usually prefer morning appointments with Mike from Comfort Air. He's available Thursday at 9am."

### 14.6 Provider Performance Gamification
- Badges for response time, completion rate, customer satisfaction
- Leaderboards within teams
- Incentive tracking for productivity goals

### 14.7 Real-Time Job Tracking
- Customer can see live status: "Mike is on his way (ETA 15 min)" → "Service in progress" → "Wrapping up"
- GPS-based ETA updates (mobile app integration)

### 14.8 Post-Service Workflow
- Automatic follow-up: "How was your AC repair? Rate your experience"
- Photo documentation: before/after photos attached to booking
- Digital invoice/receipt generation linked to booking
- Warranty tracking tied to completed services

### 14.9 Multi-Day Project Scheduling
- Large projects (kitchen remodel) span multiple days
- PJ helps schedule the sequence: "Day 1: Demo, Day 2-3: Plumbing, Day 4-5: Tile..."
- Gantt-chart style project view for providers

### 14.10 Neighborhood Clustering
- Group nearby appointments to minimize travel: "You have a job on Oak St at 10am. There's a new request on Elm St (0.3 miles away) at 1pm - want to take it?"
- Heat map visualization of service requests by area

---

## 15. Open Questions & Decisions

### Needs Decision Before Implementation

| # | Question | Options | Recommendation |
|---|----------|---------|----------------|
| 1 | **Booking model: approval vs. instant?** | A) Always require provider approval, B) Always instant, C) Configurable per offering | **C) Configurable** - `allowInstantBooking` on OfferingConfiguration lets each provider choose |
| 2 | **Travel time calculation approach** | A) Skip for MVP, B) Haversine estimation, C) Google Maps API | **B) Haversine for Phase 1**, upgrade to Google Maps later |
| 3 | **PJ as primary vs. supplementary booking interface** | A) PJ is the main way to book, B) PJ assists but traditional UI is primary, C) Both equally supported | **C) Both** - some users prefer chat, some prefer clicking a calendar |
| 4 | **Recurring bookings in MVP?** | A) Yes, B) Defer to Phase 7 | **B) Defer** - adds significant complexity; build core flow first |
| 5 | **Payment/deposit integration** | A) Include in scheduling, B) Separate feature, C) Defer | **C) Defer** - wait for Stripe billing integration (separate plan exists) |
| 6 | **Calendar sync** | A) MVP includes iCal, B) Defer all sync | **B) Defer** - iCal in Phase 7 is fine; Projulous is source of truth initially |
| 7 | **Time zones** | A) Single timezone per provider, B) Full timezone support | **A) Single timezone** for MVP; store as UTC internally, display in provider's configured TZ |
| 8 | **Booking number format** | A) BK-2026-00001, B) UUID only, C) Short alphanumeric | **A) BK-YYYY-NNNNN** - human-readable for phone/email reference |
| 9 | **Should team member skills be in MVP?** | A) Yes, B) All members can do all offerings | **B) Defer skills** - assume all members qualified for now |
| 10 | **Mobile-first or desktop-first for calendar?** | A) Mobile-first, B) Desktop-first, C) Responsive both | **C) Responsive** - calendar is heavily used on desktop but needs mobile parity |

### Technical Questions

| # | Question | Notes |
|---|----------|-------|
| 1 | Slot generation interval | Default 30 min? Configurable per provider? |
| 2 | Booking number sequence | DB sequence or application-level counter? |
| 3 | Reminder job infrastructure | Cron in NestJS (@nestjs/schedule) or separate worker? |
| 4 | Calendar component library | Build custom or use a library (e.g., FullCalendar, react-big-calendar)? |
| 5 | Availability cache | Cache computed slots in Redis or compute on-demand? |

---

*This plan was produced collaboratively by the Technical Architect, Backend Product Owner, and Frontend Product Owner agents based on thorough codebase exploration of projulous-svc, projulous-web, and projulous-shared-dto-node.*
