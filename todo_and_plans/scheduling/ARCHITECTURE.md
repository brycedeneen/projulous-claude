# Scheduling System Architecture

> **ADR-001**: Scheduling & Booking System for Projulous
> **Status**: Proposed
> **Author**: Technical Architect Agent
> **Date**: 2026-02-09

---

## 1. Overview & Goals

The Scheduling System transforms Projulous from a service provider discovery platform into a full booking and appointment management system. It enables homeowners to book service providers directly through the PJ AI assistant or manual scheduling, while giving service providers complete control over their availability, team assignments, and calendar.

### Goals
- Enable homeowners to book service appointments through PJ AI or direct scheduling
- Give service providers configurable business hours, time-off, and per-offering duration settings
- Support multi-member teams with skill-based assignment and availability intersection
- Provide real-time availability calculation accounting for existing appointments, buffer times, and travel time
- Integrate with the existing conversation and notification systems
- Future-proof for Google Calendar / iCal sync
- Generate utilization, revenue, and scheduling analytics

### Non-Goals (Phase 1)
- Payment processing (invoicing exists but payment gateway is separate)
- Recurring appointment series (designed for but not implemented in Phase 1)
- Real-time WebSocket push for calendar updates (use polling initially)
- External calendar sync implementation (schema prepared, sync deferred)

---

## 2. Entity Design

### 2.1 New Entities

#### 2.1.1 `ServiceProviderAvailability` (Table: `ServiceProviderAvailabilities`)

Represents recurring weekly business hours for a service provider. Each row is one time window on one day of the week.

```
serviceProviderAvailabilityId: UUID (PK)
dayOfWeek: integer (0=Sunday, 6=Saturday) NOT NULL
startTime: time NOT NULL (e.g., '08:00:00')
endTime: time NOT NULL (e.g., '17:00:00')
isActive: boolean NOT NULL DEFAULT true
timezone: varchar(64) NOT NULL DEFAULT 'America/New_York'

// Relations
serviceProviderId: UUID FK -> ServiceProviders NOT NULL
userId: UUID FK -> Users NULL (if null, applies to entire SP; if set, applies to specific team member)

// StandardFields
standardFields: StandardFields
```

**Design notes:**
- A service provider with no availability rows is considered "not accepting bookings"
- Multiple rows per day allow split schedules (e.g., 8AM-12PM, 1PM-5PM for lunch breaks)
- `userId` being nullable allows company-wide defaults vs. per-member overrides
- `timezone` stored per-row to support multi-timezone teams

#### 2.1.2 `ServiceProviderTimeOff` (Table: `ServiceProviderTimeOffs`)

Represents blocked-out periods (vacations, holidays, sick days).

```
serviceProviderTimeOffId: UUID (PK)
title: varchar(128) NOT NULL
reason: TimeOffReasonENUM NOT NULL DEFAULT 'OTHER'
startDateTime: timestamp NOT NULL
endDateTime: timestamp NOT NULL
allDay: boolean NOT NULL DEFAULT true
isRecurringAnnual: boolean NOT NULL DEFAULT false

// Relations
serviceProviderId: UUID FK -> ServiceProviders NOT NULL
userId: UUID FK -> Users NULL (if null, applies to entire SP)

// StandardFields
standardFields: StandardFields
```

**Design notes:**
- `isRecurringAnnual` enables annual holidays without re-entry
- Overlapping time-off ranges are allowed (e.g., company holiday + personal vacation)

#### 2.1.3 `OfferingDuration` (Table: `OfferingDurations`)

Defines duration and pricing tiers for a specific offering. A single offering may have multiple duration/pricing options (e.g., "HVAC Inspection: 1hr/$99" vs "HVAC Full Service: 3hr/$249").

```
offeringDurationId: UUID (PK)
name: varchar(128) NOT NULL
description: text NULL
durationMinutes: integer NOT NULL
priceAmountCents: integer NULL (null = "contact for quote")
priceCurrency: varchar(3) NOT NULL DEFAULT 'USD'
bufferMinutesBefore: integer NOT NULL DEFAULT 0
bufferMinutesAfter: integer NOT NULL DEFAULT 15
isActive: boolean NOT NULL DEFAULT true
sortOrder: integer NOT NULL DEFAULT 0

// Relations
serviceProviderOfferingId: UUID FK -> ServiceProviderOfferings NOT NULL

// StandardFields
standardFields: StandardFields
```

**Design notes:**
- `bufferMinutesBefore/After` enables automatic padding between appointments (travel time, cleanup, etc.)
- `priceAmountCents` stored in cents to avoid floating-point issues
- Multiple durations per offering supports tiered service levels
- `sortOrder` controls display order in UI

#### 2.1.4 `BookingRequest` (Table: `BookingRequests`)

Represents a customer's request to book a service. This is the initial request before confirmation.

```
bookingRequestId: UUID (PK)
requestedStartDateTime: timestamp NOT NULL
requestedEndDateTime: timestamp NOT NULL
alternateDateTime1: timestamp NULL
alternateDateTime2: timestamp NULL
customerNotes: text NULL
status: BookingRequestStatusENUM NOT NULL DEFAULT 'PENDING'
source: BookingSourceENUM NOT NULL DEFAULT 'MANUAL'
expiresAt: timestamp NULL (auto-decline deadline)
declineReason: text NULL

// Relations
customerProjectId: UUID FK -> CustomerProjects NOT NULL
serviceProviderId: UUID FK -> ServiceProviders NOT NULL
offeringDurationId: UUID FK -> OfferingDurations NOT NULL
requestedByUserId: UUID FK -> Users NOT NULL (the customer)
customerPlaceId: UUID FK -> CustomerPlaces NULL (job location)
conversationId: UUID FK -> Conversations NULL (if booked via PJ AI)

// StandardFields
standardFields: StandardFields
```

**Design notes:**
- `alternateDateTime1/2` allows customers to propose up to 3 time slots, increasing booking success rate
- `expiresAt` prevents stale requests from blocking availability indefinitely
- `source` tracks whether booking came from AI conversation, manual web entry, or mobile app
- Links to `conversationId` when booking originates from PJ AI chat

#### 2.1.5 `Booking` (Table: `Bookings`)

Represents a confirmed booking. Created when a BookingRequest is accepted (or when an SP creates a booking directly).

```
bookingId: UUID (PK)
confirmedStartDateTime: timestamp NOT NULL
confirmedEndDateTime: timestamp NOT NULL
status: BookingStatusENUM NOT NULL DEFAULT 'CONFIRMED'
customerNotes: text NULL
providerNotes: text NULL
cancellationReason: text NULL
cancelledByUserId: UUID FK -> Users NULL
rescheduledFromBookingId: UUID FK -> Bookings NULL (self-reference for reschedule chain)
totalAmountCents: integer NULL
priceCurrency: varchar(3) NOT NULL DEFAULT 'USD'

// Relations
bookingRequestId: UUID FK -> BookingRequests NULL (null if SP-initiated)
customerProjectId: UUID FK -> CustomerProjects NOT NULL
serviceProviderId: UUID FK -> ServiceProviders NOT NULL
offeringDurationId: UUID FK -> OfferingDurations NOT NULL
customerPlaceId: UUID FK -> CustomerPlaces NULL (job location)
scheduleEntryId: UUID FK -> ScheduleEntries NOT NULL (auto-created)

// StandardFields
standardFields: StandardFields
```

**Design notes:**
- Every confirmed booking creates a corresponding `ScheduleEntry` (1:1 relationship)
- `rescheduledFromBookingId` creates a chain of rescheduled bookings for audit history
- `cancelledByUserId` tracks who cancelled (customer vs. provider) for dispute resolution
- `totalAmountCents` can differ from `OfferingDuration.priceAmountCents` for custom quotes

#### 2.1.6 `BookingAssignment` (Table: `BookingAssignments`)

Assigns specific team members to a booking. Supports multi-member jobs.

```
bookingAssignmentId: UUID (PK)
role: BookingAssignmentRoleENUM NOT NULL DEFAULT 'PRIMARY'
status: BookingAssignmentStatusENUM NOT NULL DEFAULT 'ASSIGNED'
responseNote: text NULL

// Relations
bookingId: UUID FK -> Bookings NOT NULL
userId: UUID FK -> Users NOT NULL (team member)

// StandardFields
standardFields: StandardFields
```

**Design notes:**
- `role` distinguishes lead technician from assistants
- `status` allows individual team members to accept/decline assignments
- A booking with no assignments is handled by the SP owner by default

#### 2.1.7 `CalendarSync` (Table: `CalendarSyncs`)

Stores external calendar sync configuration for future Google Calendar/iCal integration.

```
calendarSyncId: UUID (PK)
provider: CalendarSyncProviderENUM NOT NULL
externalCalendarId: varchar(512) NULL
accessToken: text NULL (encrypted)
refreshToken: text NULL (encrypted)
syncDirection: CalendarSyncDirectionENUM NOT NULL DEFAULT 'BIDIRECTIONAL'
lastSyncAt: timestamp NULL
syncStatus: CalendarSyncStatusENUM NOT NULL DEFAULT 'ACTIVE'
syncError: text NULL

// Relations
userId: UUID FK -> Users NOT NULL
serviceProviderId: UUID FK -> ServiceProviders NULL

// StandardFields
standardFields: StandardFields
```

### 2.2 Modified Entities

#### 2.2.1 `ScheduleEntry` (Add fields)

```
// NEW FIELDS:
bookingId: UUID FK -> Bookings NULL (links schedule entry to a booking)
entryType: ScheduleEntryTypeENUM NOT NULL DEFAULT 'MANUAL'
  (MANUAL | BOOKING | TIME_OFF | TRAVEL_BUFFER | EXTERNAL_SYNC)
```

**Rationale:** The existing ScheduleEntry becomes the unified calendar view. Every booking auto-creates a ScheduleEntry, but SPs can also have manual entries, time-off blocks, and travel buffers on their calendar.

#### 2.2.2 `ServiceProviderOffering` (Add fields)

```
// NEW FIELDS:
defaultDurationMinutes: integer NULL (quick-setup default, before OfferingDuration tiers are configured)
acceptingBookings: boolean NOT NULL DEFAULT false
```

**Rationale:** `acceptingBookings` provides a simple on/off toggle. `defaultDurationMinutes` allows basic scheduling before the SP sets up detailed OfferingDuration tiers.

---

## 3. New Enums

### 3.1 `BookingRequestStatusENUM`
```typescript
export enum BookingRequestStatusENUM {
  PENDING = 'PENDING',
  ACCEPTED = 'ACCEPTED',
  DECLINED = 'DECLINED',
  EXPIRED = 'EXPIRED',
  CANCELLED_BY_CUSTOMER = 'CANCELLED_BY_CUSTOMER',
  WITHDRAWN = 'WITHDRAWN',
}
```

### 3.2 `BookingStatusENUM`
```typescript
export enum BookingStatusENUM {
  CONFIRMED = 'CONFIRMED',
  IN_PROGRESS = 'IN_PROGRESS',
  COMPLETED = 'COMPLETED',
  CANCELLED = 'CANCELLED',
  NO_SHOW = 'NO_SHOW',
  RESCHEDULED = 'RESCHEDULED',
}
```

### 3.3 `BookingSourceENUM`
```typescript
export enum BookingSourceENUM {
  MANUAL = 'MANUAL',
  PJ_AI = 'PJ_AI',
  WEB_CUSTOMER = 'WEB_CUSTOMER',
  MOBILE_CUSTOMER = 'MOBILE_CUSTOMER',
}
```

### 3.4 `BookingAssignmentRoleENUM`
```typescript
export enum BookingAssignmentRoleENUM {
  PRIMARY = 'PRIMARY',
  ASSISTANT = 'ASSISTANT',
  SUPERVISOR = 'SUPERVISOR',
}
```

### 3.5 `BookingAssignmentStatusENUM`
```typescript
export enum BookingAssignmentStatusENUM {
  ASSIGNED = 'ASSIGNED',
  ACCEPTED = 'ACCEPTED',
  DECLINED = 'DECLINED',
}
```

### 3.6 `TimeOffReasonENUM`
```typescript
export enum TimeOffReasonENUM {
  VACATION = 'VACATION',
  HOLIDAY = 'HOLIDAY',
  SICK = 'SICK',
  PERSONAL = 'PERSONAL',
  TRAINING = 'TRAINING',
  OTHER = 'OTHER',
}
```

### 3.7 `ScheduleEntryTypeENUM`
```typescript
export enum ScheduleEntryTypeENUM {
  MANUAL = 'MANUAL',
  BOOKING = 'BOOKING',
  TIME_OFF = 'TIME_OFF',
  TRAVEL_BUFFER = 'TRAVEL_BUFFER',
  EXTERNAL_SYNC = 'EXTERNAL_SYNC',
}
```

### 3.8 `CalendarSyncProviderENUM`
```typescript
export enum CalendarSyncProviderENUM {
  GOOGLE_CALENDAR = 'GOOGLE_CALENDAR',
  APPLE_ICAL = 'APPLE_ICAL',
  OUTLOOK = 'OUTLOOK',
}
```

### 3.9 `CalendarSyncDirectionENUM`
```typescript
export enum CalendarSyncDirectionENUM {
  IMPORT_ONLY = 'IMPORT_ONLY',
  EXPORT_ONLY = 'EXPORT_ONLY',
  BIDIRECTIONAL = 'BIDIRECTIONAL',
}
```

### 3.10 `CalendarSyncStatusENUM`
```typescript
export enum CalendarSyncStatusENUM {
  ACTIVE = 'ACTIVE',
  PAUSED = 'PAUSED',
  ERROR = 'ERROR',
  DISCONNECTED = 'DISCONNECTED',
}
```

---

## 4. Availability Engine

### 4.1 Algorithm Overview

The availability engine computes open time slots for a given service provider, offering, and date range. It is the core of the scheduling system.

```
getAvailableSlots(serviceProviderId, offeringDurationId, dateRange, customerPlaceId?)
  -> AvailableSlot[]
```

### 4.2 Computation Steps

```
1. LOAD base availability
   - Fetch ServiceProviderAvailability rows for the SP (and optional specific team member)
   - Filter to isActive = true
   - Expand recurring weekly windows into concrete datetime ranges for the requested date range

2. SUBTRACT time-off blocks
   - Fetch ServiceProviderTimeOff rows overlapping the date range
   - Include isRecurringAnnual entries (match month+day regardless of year)
   - Remove any overlapping ranges from the available windows

3. SUBTRACT existing schedule entries
   - Fetch ScheduleEntries for the SP's user(s) in the date range
   - Where status != CANCELLED
   - Include buffer times (bufferMinutesBefore + bufferMinutesAfter from OfferingDuration)
   - Remove overlapping ranges

4. APPLY offering duration constraints
   - Fetch OfferingDuration for the requested offering
   - Split remaining available windows into discrete slots of durationMinutes length
   - Slots must start on 15-minute boundaries (configurable granularity)
   - Discard slots that are too short for the offering

5. (OPTIONAL) APPLY travel time gaps
   - If customerPlaceId is provided:
     - For each adjacent existing booking, estimate travel time using PostalCodeLatLong
     - Add travel gap between consecutive appointments
     - Remove slots that would violate travel time constraints

6. APPLY booking limits (overbooking protection)
   - If SP has a max-daily-bookings setting, filter out days that are full
   - If SP has a max-concurrent setting, filter out overlapping slots

7. RETURN sorted AvailableSlot[] with:
   - startDateTime, endDateTime
   - offeringDurationId
   - travelTimeMinutesFromPrevious (if calculated)
   - slotScore (0-100, a "quality" metric favoring contiguous blocks and minimal travel)
```

### 4.3 Slot Quality Scoring

Each available slot gets a score (0-100) to help PJ AI recommend the best times:

| Factor | Weight | Logic |
|--------|--------|-------|
| Time-of-day preference | 30% | Morning slots score higher for most service types |
| Adjacent to existing booking | 25% | Minimizes travel, maximizes SP productivity |
| Distance from customer | 20% | Closer SPs score higher |
| Day completeness | 15% | Slots that fill gaps in the SP's day score higher |
| Lead time | 10% | Slots 24-48h out score slightly higher than same-day |

### 4.4 Team Availability Intersection

For multi-member bookings:
```
getTeamAvailableSlots(serviceProviderId, offeringDurationId, dateRange, requiredMemberCount?)
  1. Fetch all team members via RoleMembership
  2. For each member, compute individual availability (steps 1-6 above)
  3. Find intersection of N members' availability (where N = requiredMemberCount or 1)
  4. Return slots where at least N members are simultaneously free
```

---

## 5. Booking Flow

### 5.1 State Machine

```
                    +----------------+
                    |   Customer     |
                    |   Requests     |
                    +-------+--------+
                            |
                    +-------v--------+
                    |    PENDING     |<------ BookingRequest created
                    +-------+--------+
                            |
              +-------------+----------------+
              |             |                |
       +------v----+  +----v------+  +-------v-------+
       |  DECLINED  |  |  ACCEPTED |  |    EXPIRED    |
       |            |  |           |  | (auto after   |
       |            |  |           |  |  48h default) |
       +-----------+  +----+------+  +---------------+
                           |
                    +------v--------+
                    |   CONFIRMED   |<------ Booking + ScheduleEntry created
                    +------+--------+
                           |
              +------------+----------------+-----------------+
              |            |                |                 |
       +------v----+  +---v--------+  +----v------+  +------v---------+
       | CANCELLED  |  |IN_PROGRESS |  |  NO_SHOW  |  |  RESCHEDULED   |
       |           |  |            |  |           |  | (new Booking    |
       +-----------+  +---+--------+  +-----------+  |  created)       |
                          |                           +----------------+
                   +------v--------+
                   |   COMPLETED   |
                   +---------------+
```

### 5.2 Customer-Initiated Booking Flow

1. Customer selects a service provider offering
2. System calls `getAvailableSlots()` for the next 14 days
3. Customer picks preferred slot (+ optional alternates)
4. System creates `BookingRequest` with status PENDING
5. SP receives notification (push + in-app + email)
6. SP accepts -> System creates `Booking` (CONFIRMED) + `ScheduleEntry` + `BookingAssignment`
7. SP declines -> BookingRequest marked DECLINED, customer notified with suggested alternatives
8. No response -> BookingRequest expires after configurable window (default 48h)

### 5.3 SP-Initiated Booking Flow (Direct Scheduling)

1. SP creates booking directly from their calendar
2. System creates `Booking` (CONFIRMED) + `ScheduleEntry` (no BookingRequest needed)
3. Customer receives confirmation notification
4. `bookingRequestId` is NULL on the Booking

### 5.4 Reschedule Flow

1. Either party requests reschedule
2. System creates new BookingRequest with `source` indicating reschedule
3. Original Booking status set to RESCHEDULED
4. New Booking links back via `rescheduledFromBookingId`
5. Original ScheduleEntry cancelled, new one created

### 5.5 Cancellation Rules

- Customer can cancel with no penalty if > 24h before start (configurable per SP)
- SP can cancel anytime, but system tracks cancellation rate for quality metrics
- Cancelled bookings soft-delete the associated ScheduleEntry (via standardFields.deletedDate)

---

## 6. Team Scheduling

### 6.1 Assignment Logic

When a booking is confirmed, team member assignment follows this priority:

1. **SP-selected**: If the SP explicitly assigns a member during acceptance, use that
2. **Skill-match**: Match OfferingType to team members who have that skill (future: TeamMemberSkill entity)
3. **Least-busy**: Among qualified members, pick the one with the fewest bookings that day
4. **Round-robin fallback**: If tied, rotate based on last assignment date

### 6.2 Multi-Member Jobs

Some jobs require multiple team members (e.g., HVAC install needs 2 technicians):

- `OfferingDuration` gets an optional `requiredTeamSize` field (default 1)
- Availability engine intersects N members' schedules
- Multiple `BookingAssignment` rows created for the same booking
- Each assigned member sees the booking on their personal schedule

### 6.3 Team Calendar View

The SP admin sees a team calendar showing:
- All members' schedules side-by-side (day/week view)
- Color-coded by booking status
- Drag-and-drop reassignment (future enhancement)
- Unassigned bookings highlighted for attention

---

## 7. PJ AI Integration

### 7.1 New Conversation Type

Add to `ConversationTypeENUM`:
```
BOOKING = 'BOOKING'
```

### 7.2 Booking Conversation Flow

PJ AI already handles service discovery (FindServiceService). The booking flow extends this:

```
1. Customer: "I need an HVAC repair"
   -> PJ uses FindServiceService to identify offering type + nearby SPs

2. PJ: "I found 3 HVAC providers near you. Would you like to book an appointment?"
   -> New step: if customer says yes, transition to BOOKING conversation type

3. PJ: "Great! [SP Name] has availability this week. Here are their best times:"
   -> Backend calls getAvailableSlots() with slotScore ranking
   -> PJ presents top 3-5 slots in natural language

4. Customer: "Thursday at 2pm works"
   -> Backend creates BookingRequest
   -> PJ confirms: "I've requested Thursday 2:00-3:30 PM with [SP Name].
      They'll confirm within 48 hours. I'll notify you!"

5. [Async] SP accepts/declines
   -> Notification sent to customer
   -> If customer returns to conversation, PJ provides status update
```

### 7.3 Smart Suggestions

PJ AI can proactively suggest bookings when:
- A customer project has been open for > 7 days without scheduling
- Seasonal service reminders (HVAC tune-up before summer/winter)
- Follow-up appointments after completed work

### 7.4 AI Schema Extensions

Add to `discoverySchemas.ts` a new Zod schema:
```typescript
export const bookingSlotSchema = z.object({
  startDateTime: z.string().datetime(),
  endDateTime: z.string().datetime(),
  serviceProviderName: z.string(),
  offeringName: z.string(),
  durationMinutes: z.number(),
  priceDescription: z.string(),
});

export const bookingSlotsSchema = z.object({
  availableSlots: z.array(bookingSlotSchema),
  recommendation: z.string().describe('Natural language recommendation for the best slot'),
});
```

---

## 8. Travel Time Calculation

### 8.1 Approach

Use the existing `PostalCodeLatLong` table for distance-based estimation. This is an approximation suitable for scheduling buffer purposes (not turn-by-turn navigation).

### 8.2 Algorithm

```typescript
function estimateTravelTimeMinutes(
  fromPostalCode: string,
  toPostalCode: string
): number {
  // 1. Look up lat/long for both postal codes from PostalCodeLatLong table
  // 2. Calculate haversine distance in miles
  // 3. Estimate travel time:
  //    - Urban (< 10 miles): distance * 3 min/mile (accounts for traffic)
  //    - Suburban (10-30 miles): distance * 2 min/mile
  //    - Rural (> 30 miles): distance * 1.5 min/mile
  // 4. Round up to nearest 15 minutes
  // 5. Cap at configurable maximum (default: 90 minutes)
}
```

### 8.3 Integration Points

- **Availability Engine (Step 5)**: After calculating raw available slots, insert travel buffer entries between consecutive bookings at different locations
- **ScheduleEntry**: Auto-created `TRAVEL_BUFFER` type entries on the calendar
- **Booking display**: Show estimated travel time to customer ("Your technician will arrive between 2:00-2:30 PM")

### 8.4 Data Requirements

- `CustomerPlace.zipCode` provides customer location
- `ServiceProviderOffering.centerPointPostalCode` provides SP base location
- Previous booking's `CustomerPlace.zipCode` provides the "from" location for travel calculation

---

## 9. Calendar Sync Strategy

### 9.1 Phase 1: Export-Only (iCal Feed)

Generate a unique, read-only iCal URL per user:
```
GET /v1/calendar/:userId/feed.ics?token=<unique-token>
```
- Standard RFC 5545 iCal format
- Includes all ScheduleEntries for the user
- Subscribable in Google Calendar, Apple Calendar, Outlook
- Token-based auth (no session required)
- Refreshed on each request (no caching)

### 9.2 Phase 2: Google Calendar OAuth (Future)

- OAuth2 flow to connect Google Calendar
- Two-way sync via Google Calendar API
- `CalendarSync` entity stores tokens
- Background job polls for external changes every 5 minutes
- Conflict resolution: Projulous is source of truth for bookings; external events become "blocked" time

### 9.3 Phase 3: Full Bidirectional (Future)

- Import external calendar events as `ScheduleEntry` with type `EXTERNAL_SYNC`
- These block availability but don't appear as bookings
- Webhooks for real-time sync (Google push notifications)

---

## 10. Reporting Data Model

### 10.1 Key Metrics

| Metric | Calculation | Entity Source |
|--------|------------|---------------|
| Utilization Rate | booked_hours / available_hours * 100 | Booking + ServiceProviderAvailability |
| Booking Acceptance Rate | accepted_requests / total_requests * 100 | BookingRequest |
| Average Response Time | avg(accepted_at - created_at) | BookingRequest |
| Revenue per Day/Week/Month | sum(totalAmountCents) | Booking (COMPLETED) |
| No-Show Rate | no_show_bookings / total_bookings * 100 | Booking |
| Cancellation Rate | cancelled_bookings / total_bookings * 100 | Booking |
| Average Job Duration | avg(endDateTime - startDateTime) | Booking (COMPLETED) |
| Customer Repeat Rate | customers_with_2+_bookings / total_customers | Booking |
| Team Member Productivity | bookings_per_member_per_day | BookingAssignment + Booking |
| Travel Time Overhead | sum(travel_buffer_minutes) / sum(booking_minutes) | ScheduleEntry |

### 10.2 Reporting Queries (GraphQL)

```graphql
type ScheduleAnalytics {
  utilizationRate: Float!
  bookingAcceptanceRate: Float!
  averageResponseTimeHours: Float!
  totalRevenueForPeriod: Int!
  noShowRate: Float!
  cancellationRate: Float!
  bookingsCount: Int!
  completedBookingsCount: Int!
}

type Query {
  getScheduleAnalytics(
    serviceProviderId: String!
    startDate: String!
    endDate: String!
  ): ScheduleAnalytics

  getTeamUtilization(
    serviceProviderId: String!
    startDate: String!
    endDate: String!
  ): [TeamMemberUtilization!]!
}
```

### 10.3 Performance Considerations

- All analytics queries use the **read replica**
- For large date ranges (> 90 days), consider materializing aggregates in a `ScheduleAnalyticsSnapshot` table (daily cron job)
- Indexes on: `Bookings(serviceProviderId, confirmedStartDateTime)`, `BookingRequests(serviceProviderId, status, createdDate)`

---

## 11. Event Architecture

### 11.1 New EventTypeENUM Values

```typescript
// Booking Request
BOOKING_REQUEST_CREATE = 'booking_request_create',
BOOKING_REQUEST_ACCEPT = 'booking_request_accept',
BOOKING_REQUEST_DECLINE = 'booking_request_decline',
BOOKING_REQUEST_EXPIRE = 'booking_request_expire',
BOOKING_REQUEST_CANCEL = 'booking_request_cancel',

// Booking
BOOKING_CONFIRM = 'booking_confirm',
BOOKING_START = 'booking_start',
BOOKING_COMPLETE = 'booking_complete',
BOOKING_CANCEL = 'booking_cancel',
BOOKING_RESCHEDULE = 'booking_reschedule',
BOOKING_NO_SHOW = 'booking_no_show',

// Booking Assignment
BOOKING_ASSIGNMENT_CREATE = 'booking_assignment_create',
BOOKING_ASSIGNMENT_ACCEPT = 'booking_assignment_accept',
BOOKING_ASSIGNMENT_DECLINE = 'booking_assignment_decline',

// Availability
AVAILABILITY_UPDATE = 'availability_update',
TIME_OFF_CREATE = 'time_off_create',
TIME_OFF_DELETE = 'time_off_delete',

// Offering Duration
OFFERING_DURATION_CREATE = 'offering_duration_create',
OFFERING_DURATION_UPDATE = 'offering_duration_update',
OFFERING_DURATION_DELETE = 'offering_duration_delete',
```

### 11.2 New NotificationTypeENUM Values

```typescript
BOOKING_REQUEST_RECEIVED = 'BOOKING_REQUEST_RECEIVED',  // SP gets this
BOOKING_CONFIRMED = 'BOOKING_CONFIRMED',                // Customer gets this
BOOKING_DECLINED = 'BOOKING_DECLINED',                  // Customer gets this
BOOKING_CANCELLED = 'BOOKING_CANCELLED',                // Both parties
BOOKING_RESCHEDULED = 'BOOKING_RESCHEDULED',           // Both parties
BOOKING_REMINDER_24H = 'BOOKING_REMINDER_24H',         // Both parties
BOOKING_REMINDER_1H = 'BOOKING_REMINDER_1H',           // Both parties
BOOKING_STARTED = 'BOOKING_STARTED',                    // Customer gets this
BOOKING_COMPLETED = 'BOOKING_COMPLETED',                // Customer gets this
BOOKING_NO_SHOW = 'BOOKING_NO_SHOW',                   // SP gets this
BOOKING_ASSIGNMENT = 'BOOKING_ASSIGNMENT',              // Team member gets this
BOOKING_REQUEST_EXPIRING = 'BOOKING_REQUEST_EXPIRING',  // SP gets this (12h before expiry)
```

### 11.3 Event Controller Design

New event controller: `BookingEventController`

Responsibilities:
- **BOOKING_REQUEST_CREATE**: Send notification to SP, start expiry timer
- **BOOKING_REQUEST_ACCEPT**: Create Booking + ScheduleEntry + Assignments, notify customer
- **BOOKING_REQUEST_EXPIRE**: Auto-decline, notify customer with alternative suggestions
- **BOOKING_CONFIRM**: Schedule 24h and 1h reminder notifications
- **BOOKING_CANCEL**: Soft-delete ScheduleEntry, notify parties, free up availability
- **BOOKING_COMPLETE**: Trigger analytics update, prompt customer for review

### 11.4 Scheduled Jobs (Cron)

| Job | Schedule | Purpose |
|-----|----------|---------|
| Expire pending requests | Every 15 min | Mark BookingRequests past `expiresAt` as EXPIRED |
| Send 24h reminders | Daily at 6 AM | Find bookings starting tomorrow, send reminders |
| Send 1h reminders | Every 15 min | Find bookings starting in ~1h, send reminders |
| Auto-complete bookings | Hourly | Mark IN_PROGRESS bookings past endDateTime as COMPLETED |
| Analytics snapshot | Daily at midnight | Materialize daily analytics for reporting |

---

## 12. API Contract Overview

### 12.1 GraphQL Queries (Read Operations)

```graphql
# Availability
getAvailableSlots(
  serviceProviderId: String!
  offeringDurationId: String!
  startDate: String!
  endDate: String!
  customerPlaceId: String
): [AvailableSlot!]!

getServiceProviderAvailability(serviceProviderId: String!): [ServiceProviderAvailability!]!
getServiceProviderTimeOffs(serviceProviderId: String!, startDate: String!, endDate: String!): [ServiceProviderTimeOff!]!

# Bookings (Customer perspective)
getMyBookings(startDate: String, endDate: String, status: BookingStatusENUM): [Booking!]!
getMyBookingRequests(status: BookingRequestStatusENUM): [BookingRequest!]!
getBooking(bookingId: String!): Booking

# Bookings (SP perspective)
getProviderBookings(serviceProviderId: String!, startDate: String!, endDate: String!, status: BookingStatusENUM): [Booking!]!
getProviderBookingRequests(serviceProviderId: String!, status: BookingRequestStatusENUM): [BookingRequest!]!

# Schedule (existing, enhanced)
getMySchedule(startDate: String!, endDate: String!): [ScheduleEntry!]!  # already exists
getTeamSchedule(serviceProviderId: String!, startDate: String!, endDate: String!): [ScheduleEntry!]!  # new

# Offering Durations
getOfferingDurations(serviceProviderOfferingId: String!): [OfferingDuration!]!

# Analytics
getScheduleAnalytics(serviceProviderId: String!, startDate: String!, endDate: String!): ScheduleAnalytics
```

### 12.2 REST Endpoints (Write Operations)

```
# Availability Management
POST   /v1/availability                  - Create availability window
PATCH  /v1/availability/:id              - Update availability window
DELETE /v1/availability/:id              - Delete availability window

POST   /v1/time-off                      - Create time-off block
PATCH  /v1/time-off/:id                  - Update time-off block
DELETE /v1/time-off/:id                  - Delete time-off block

# Offering Duration Management
POST   /v1/offering-duration             - Create offering duration
PATCH  /v1/offering-duration/:id         - Update offering duration
DELETE /v1/offering-duration/:id         - Delete offering duration

# Booking Request Flow
POST   /v1/booking-request               - Customer creates booking request
PATCH  /v1/booking-request/:id/accept    - SP accepts request
PATCH  /v1/booking-request/:id/decline   - SP declines request
DELETE /v1/booking-request/:id           - Customer cancels/withdraws request

# Booking Management
POST   /v1/booking                       - SP creates direct booking
PATCH  /v1/booking/:id                   - Update booking details
PATCH  /v1/booking/:id/start             - Mark booking in progress
PATCH  /v1/booking/:id/complete          - Mark booking completed
PATCH  /v1/booking/:id/cancel            - Cancel booking
PATCH  /v1/booking/:id/no-show           - Mark as no-show
POST   /v1/booking/:id/reschedule        - Initiate reschedule (creates new BookingRequest)

# Booking Assignment
POST   /v1/booking-assignment            - Assign team member
PATCH  /v1/booking-assignment/:id        - Update assignment (accept/decline)
DELETE /v1/booking-assignment/:id        - Remove assignment

# Calendar Sync (Future)
POST   /v1/calendar-sync                 - Connect external calendar
DELETE /v1/calendar-sync/:id             - Disconnect external calendar

# iCal Feed (Phase 1)
GET    /v1/calendar/:userId/feed.ics     - iCal feed (token auth)
```

---

## 13. Permission Model

### 13.1 New PermissionENUM Values

```typescript
// Booking permissions
BOOKING_CREATE = 'BOOKING_CREATE',
BOOKING_READ = 'BOOKING_READ',
BOOKING_MODIFY = 'BOOKING_MODIFY',
BOOKING_DELETE = 'BOOKING_DELETE',

// Availability management
AVAILABILITY_CREATE = 'AVAILABILITY_CREATE',
AVAILABILITY_READ = 'AVAILABILITY_READ',
AVAILABILITY_MODIFY = 'AVAILABILITY_MODIFY',
AVAILABILITY_DELETE = 'AVAILABILITY_DELETE',

// Offering duration management
OFFERING_DURATION_CREATE = 'OFFERING_DURATION_CREATE',
OFFERING_DURATION_READ = 'OFFERING_DURATION_READ',
OFFERING_DURATION_MODIFY = 'OFFERING_DURATION_MODIFY',
OFFERING_DURATION_DELETE = 'OFFERING_DURATION_DELETE',

// Analytics
SCHEDULE_ANALYTICS_READ = 'SCHEDULE_ANALYTICS_READ',
```

### 13.2 Role-Permission Mapping

| Permission | Customer | SP Owner | SP Member | Admin |
|-----------|----------|----------|-----------|-------|
| BOOKING_CREATE | Yes | Yes | No | Yes |
| BOOKING_READ | Own | Team | Own | All |
| BOOKING_MODIFY | Own | Team | Own | All |
| BOOKING_DELETE | Own | Team | No | All |
| AVAILABILITY_* | No | Yes | Own | All |
| OFFERING_DURATION_* | No | Yes | No | All |
| SCHEDULE_ANALYTICS_READ | No | Yes | No | All |
| SCHEDULE_READ (existing) | Own | Team | Own | All |

---

## 14. Implementation Phases

### Phase 1: Foundation (MVP)
**Goal**: Basic availability + booking flow

1. Create new enums in `projulous-shared-dto-node/shared/enums/`
2. Create `ServiceProviderAvailability` entity
3. Create `ServiceProviderTimeOff` entity
4. Create `OfferingDuration` entity
5. Modify `ScheduleEntry` (add entryType, bookingId)
6. Modify `ServiceProviderOffering` (add defaultDurationMinutes, acceptingBookings)
7. Create `BookingRequest` entity
8. Create `Booking` entity
9. Implement `AvailabilityService` with basic slot calculation (steps 1-4)
10. Implement `BookingRequestService` + `BookingService`
11. Create REST controllers + GraphQL resolvers
12. Add new EventTypeENUM values + event controllers
13. Add new permissions and seed them

### Phase 2: Team & Travel
**Goal**: Multi-member scheduling + travel time

1. Create `BookingAssignment` entity
2. Implement team availability intersection (Algorithm step for team)
3. Implement travel time estimation using PostalCodeLatLong
4. Add travel buffer ScheduleEntry auto-creation
5. Build team calendar GraphQL query

### Phase 3: AI Booking
**Goal**: PJ AI conversation-driven booking

1. Add BOOKING conversation type
2. Extend PJ AI prompts for booking flow
3. Implement smart slot suggestions (slot scoring)
4. Add proactive booking suggestions

### Phase 4: Calendar Sync & Analytics
**Goal**: External calendar + reporting

1. Create `CalendarSync` entity
2. Implement iCal feed endpoint
3. Build analytics queries
4. Implement scheduled cron jobs (reminders, expiry, auto-complete)
5. Build analytics dashboard queries

---

## 15. Entity Relationship Diagram (Text)

```
ServiceProvider
  |-- ServiceProviderOffering (1:N)
  |     +-- OfferingDuration (1:N)
  |-- ServiceProviderAvailability (1:N)
  |-- ServiceProviderTimeOff (1:N)
  |-- BookingRequest (1:N, as target SP)
  |     +-- Booking (1:1, when accepted)
  |           |-- BookingAssignment (1:N, team members)
  |           |-- ScheduleEntry (1:1, calendar entry)
  |           +-- Booking (self-ref, reschedule chain)
  +-- RoleMembership (1:N, team members)
        +-- User

CustomerProject
  |-- BookingRequest (1:N)
  +-- Booking (1:N)

CustomerPlace
  |-- BookingRequest (N:1, job location)
  +-- Booking (N:1, job location)

Conversation
  +-- BookingRequest (1:N, AI-initiated bookings)

User
  |-- ScheduleEntry (1:N)
  |-- ServiceProviderAvailability (N:1, per-member overrides)
  |-- ServiceProviderTimeOff (N:1, per-member time off)
  |-- BookingAssignment (1:N, as assigned team member)
  +-- CalendarSync (1:N)
```

---

## 16. Key Design Decisions Summary

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Separate BookingRequest vs Booking | Two entities | Clean state machine, audit trail, supports both customer-initiated and SP-initiated flows |
| Booking creates ScheduleEntry | 1:1 required relationship | Unified calendar view, existing schedule UI works immediately |
| OfferingDuration separate from Offering | 1:N relationship | Supports tiered pricing/duration without complicating Offering entity |
| Availability as weekly recurring | Rows per day-of-week | Most service providers have regular weekly schedules; simpler than complex RRULE parsing |
| Travel time via PostalCodeLatLong | Haversine + heuristic | Good enough for buffer estimation; no external API dependency or cost |
| Timezone per availability row | varchar field | Supports multi-timezone teams; avoids ambiguity |
| Buffer times on OfferingDuration | Before + after fields | Different services need different buffers (cleanup time vs. travel) |
| Slot quality scoring | Weighted algorithm | Enables AI-powered "smart" suggestions without over-engineering |
| iCal before Google sync | Export-only first | Immediate value with minimal implementation cost; Google OAuth is complex |
| Analytics on read replica | All read queries | No impact on write performance; acceptable staleness for analytics |

---

*This architecture document should be reviewed by the team lead and implementation agents before development begins. Entity developers should start with Phase 1 entities, service developers with the AvailabilityService.*
