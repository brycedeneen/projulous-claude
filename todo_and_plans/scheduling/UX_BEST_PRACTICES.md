# Scheduling Feature - UX Best Practices & Design Guidelines

*Addendum to SCHEDULING_FEATURE_PLAN.md*

---

## Table of Contents

1. [Customer Booking Experience](#1-customer-booking-experience)
2. [Service Provider Experience](#2-service-provider-experience)
3. [Accessibility & Inclusive Design](#3-accessibility--inclusive-design)
4. [Mobile Responsiveness](#4-mobile-responsiveness)
5. [Visual Design System](#5-visual-design-system)
6. [Micro-Interactions & Feedback](#6-micro-interactions--feedback)
7. [Competitive Analysis Insights](#7-competitive-analysis-insights)
8. [Common Pitfalls to Avoid](#8-common-pitfalls-to-avoid)

---

## 1. Customer Booking Experience

### 1.1 Context Before Calendar

**Principle:** Never jump straight to a calendar. Show service context first.

The booking wizard's 3-step flow (Select Service -> Pick Time -> Confirm) is correct. The key UX insight is that **Step 1 reduces cognitive load** for Step 2. When users understand what they're booking, duration, and estimated cost, they make faster time decisions.

**Recommendations:**
- Show provider card at top of flow: name, photo/logo, rating, verified badge
- Display service duration prominently next to each offering ("AC Repair - ~90 min")
- Show price upfront (even if estimate): reduces anxiety and sets expectations
- Pre-select the customer's primary place/address as default location
- If arriving from PJ conversation or provider profile, pre-fill Step 1 selections

### 1.2 Time Slot Picker Design

**Pattern: Calendar + Slot Grid (not just a calendar)**

```
┌─────────────────────────────────────────┐
│  ◀  February 2026  ▶                    │
│  Mo  Tu  We  Th  Fr  Sa  Su            │
│   2   3   4   5   6   7   8            │
│   9  [10] 11  12  13  14  15           │  ← dates with availability
│  16  17  18  19  20  21  22            │    are bold/highlighted
│  23  24  25  26  27  28                │    unavailable dates are
│                                         │    grayed out
├─────────────────────────────────────────┤
│  Tuesday, February 10                    │
│                                         │
│  Morning                                │
│  ┌────────┐  ┌────────┐  ┌────────┐   │
│  │ 8:00am │  │ 8:30am │  │ 9:00am │   │  ← large touch targets
│  └────────┘  └────────┘  └────────┘   │    (min 48x44px)
│  ┌────────┐  ┌────────┐               │
│  │ 9:30am │  │10:00am │               │
│  └────────┘  └────────┘               │
│                                         │
│  Afternoon                              │
│  ┌────────┐  ┌────────┐  ┌────────┐   │
│  │ 1:00pm │  │ 1:30pm │  │ 2:00pm │   │
│  └────────┘  └────────┘  └────────┘   │
│                                         │
│  Evening                                │
│  No availability                        │
└─────────────────────────────────────────┘
```

**Key decisions:**
- Group slots by time-of-day (Morning/Afternoon/Evening) - easier to scan than a flat list
- Highlight "recommended" or "next available" slot with a subtle accent border
- Gray out dates with zero availability on the calendar
- Show a dot/indicator under dates that have availability
- Allow direct keyboard input for date on desktop (not just calendar clicking)
- Default to the nearest date with availability, not today

### 1.3 Booking Confirmation - Reducing Anxiety

Booking confirmation is a **trust moment**. Users need reassurance that their request went through and clarity on what happens next.

**Confirmation page must include:**
1. Prominent booking number (BK-2026-00042) - large, copyable
2. Visual status badge: "Confirmed" (green) or "Awaiting Confirmation" (amber)
3. Service details: offering name, provider name + logo, date/time, duration, location
4. Price summary (even if estimate)
5. **"What happens next" section:**
   - For instant bookings: "You're all set! [Provider] will arrive at the scheduled time."
   - For approval-required: "Your request has been sent to [Provider]. They typically respond within 2 hours. We'll notify you when confirmed."
6. **Action buttons:** Add to Calendar (Google/Apple/Outlook .ics), View in My Appointments, Contact Provider
7. **Modification options:** Reschedule, Cancel - don't hide these

**Email/push confirmation** should mirror the page content. Include the booking number in the email subject line.

### 1.4 Progressive Disclosure

Don't overwhelm users with all options at once:

- **Step 1:** Only show bookable offerings (not all offerings). Show duration + price inline.
- **Step 2:** Only show available dates/times. Don't show a full calendar with everything grayed out.
- **Step 3:** Pre-fill known info (address, contact). Only ask for what's new (notes, project link).
- **"Optional" fields collapsed by default:** Customer notes, project association, special instructions - show as expandable section labeled "Add details (optional)"

### 1.5 Error States & Recovery

| Scenario | UX Response |
|----------|-------------|
| **Slot taken while browsing** | Toast notification: "This time was just booked. Here are similar times:" + auto-show next 3 available slots |
| **No availability this week** | "No openings this week. Next available: Thu Feb 20 at 9:00am. [Jump to that date]" + option to join waitlist |
| **Provider not accepting bookings** | "This provider isn't accepting online bookings right now. [Contact them directly] or [Find similar providers]" |
| **Network error during booking** | Retry button with clear message. Never leave user unsure if booking went through. |
| **Booking request declined** | "Unfortunately [Provider] couldn't accommodate this time. [See other available times] or [Try another provider]" |

### 1.6 Empty States

| Context | Empty State |
|---------|-------------|
| **No upcoming appointments** | Illustration + "No upcoming appointments. Ready to book a service?" + [Browse Providers] or [Talk to PJ] |
| **No past appointments** | "Your appointment history will appear here after your first booking." |
| **No available slots for date range** | "No openings in this date range. Try expanding your search or [join the waitlist]." |

---

## 2. Service Provider Experience

### 2.1 Calendar Dashboard - Information Hierarchy

The calendar is the **command center** for service providers. It needs to surface the right info at the right time.

**Priority order (what providers need at a glance):**
1. **Today's schedule** - what's happening now and next
2. **Pending actions** - booking requests needing response (badge count)
3. **This week overview** - how full is the schedule
4. **Team member status** - who's where doing what

**Dashboard layout recommendation:**
```
┌────────────────────────────────────────────────────┐
│  ┌──────────────────┐  ┌────────────────────────┐  │
│  │ TODAY             │  │ NEEDS ACTION        (3)│  │
│  │ 3 appointments    │  │ 2 pending requests     │  │
│  │ Next: AC Repair   │  │ 1 reschedule request   │  │
│  │ in 45 min         │  │ [View All →]           │  │
│  └──────────────────┘  └────────────────────────┘  │
│                                                      │
│  ┌──────── Calendar (Week View) ──────────────────┐ │
│  │  ...                                           │ │
│  └────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────┘
```

### 2.2 Calendar View Best Practices

**Week view (default for providers):**
- Time column on left (6am-10pm), days across top
- Current time indicator (red horizontal line)
- Booking cards color-coded by status (not by service type - status is more actionable)
- Click booking card → slide-in detail panel from right (don't navigate away from calendar)
- Drag-and-drop to reschedule (Phase 7, but design for it now with visual affordance)

**Day view:**
- More detail per booking card (customer name, address, service type, assigned team member)
- Timeline-style with wider cards

**Month view:**
- Condensed: show count badges per day ("3 bookings")
- Click day → expand or navigate to day view
- Color indicators for busy/light/off days

**Critical interaction:** Click empty slot → quick-action popover: "Block Time" or "Create Booking"

### 2.3 Booking Inbox Design

**Needs Action section should be impossible to miss:**
- Sticky at top of booking list, or badge on calendar navigation
- Sort by urgency: oldest pending first (response time matters for customer experience)
- Each pending request shows: customer name, service, requested time, how long ago requested
- **Two-click confirmation:** [Confirm] button right on the card (no extra page needed)
- Decline should ask for reason (dropdown: schedule conflict, not available, customer area too far)
- "Suggest Alternative" option when declining → opens slot picker to propose new time

### 2.4 Availability Management UX

**Business hours editor:**
- Visual weekly grid (Mon-Sun rows, time range per row)
- Toggle per day (checkmark = working, X = off)
- Time inputs as dropdowns with common increments (6:00am, 6:30am, 7:00am...)
- "Copy to all weekdays" quick action (most providers have same Mon-Fri hours)
- Separate tab/section for per-team-member overrides
- Visual preview: "You're available 45 hours/week across 6 days"

**Time-off management:**
- Calendar-based selection (click/drag date range) + form for details
- Clear distinction between one-time vs. recurring annual blocks
- Visual overlay on calendar showing blocked periods
- "Apply to" selector: whole company or specific team member

### 2.5 Team Scheduling Patterns

**Multi-column view (one column per team member):**
- Each column shows that member's day schedule
- Color-coded: booked (blue), available (white), time-off (gray stripe)
- Hovering over an available slot across 2+ members highlights the intersection
- Assignment: drag booking from "unassigned" to a team member column

**Team utilization bar:**
```
Team Utilization Today
Mike T.  ████████░░░░ 67%
Sarah L. ██████░░░░░░ 50%
Jim K.   ████████████ 100%
```
Helps providers balance workload at a glance.

---

## 3. Accessibility & Inclusive Design

### 3.1 WCAG AA Compliance Checklist for Calendar Components

| Requirement | Implementation |
|-------------|---------------|
| **Keyboard navigation** | Arrow keys move between dates/slots. Enter/Space selects. Tab moves between sections. Escape closes modals. |
| **Focus indicators** | 2px solid outline (ring-2 ring-blue-500) on focused elements. Never `outline-none` without alternative. |
| **Color contrast** | All text/background combos must meet 4.5:1 ratio minimum. Use Tailwind's accessibility-friendly palette. |
| **Screen reader labels** | Every interactive element needs aria-label. Calendar: `aria-label="Tuesday February 10, 3 slots available"`. Status badges: `aria-label="Booking status: confirmed"`. |
| **Not color-only** | Status badges use icon + text + color (not just color). Calendar availability uses number indicators + color. |
| **Focus trapping** | Modals (booking detail, confirm/cancel dialogs) trap focus within. Return focus to trigger on close. |
| **Live regions** | `aria-live="polite"` for dynamic content: slot updates, booking confirmations, error messages. |
| **Reduced motion** | `prefers-reduced-motion` media query: disable animations, transitions. Use Tailwind `motion-reduce:`. |

### 3.2 Colorblind-Safe Status Colors

Standard status colors with pattern/icon backup:

| Status | Color | Icon | Additional Indicator |
|--------|-------|------|---------------------|
| Requested | Amber/Yellow (`amber-500`) | Clock icon | Dashed border |
| Confirmed | Green (`emerald-500`) | Check circle icon | Solid border |
| In Progress | Blue (`blue-500`) | Play/arrow icon | Pulse animation |
| Completed | Gray (`gray-500`) | Check double icon | — |
| Cancelled | Red (`red-500`) | X circle icon | Strikethrough text |
| No Show | Red-orange (`orange-600`) | Alert icon | Diagonal stripe pattern |

**Always pair color with at least one other indicator** (icon, text label, border style, or pattern).

### 3.3 Touch Targets

- **Minimum:** 44x44px (WCAG), **recommended:** 48x48px
- Time slot buttons: at least 48px tall, full-width of column
- Calendar date cells: at least 44x44px with 4px gap between
- Action buttons on booking cards: 44px height minimum
- Close/dismiss buttons on modals: 44x44px

---

## 4. Mobile Responsiveness

### 4.1 Responsive Breakpoints Strategy

| Breakpoint | Calendar View | Layout |
|------------|--------------|--------|
| **< 640px (mobile)** | Agenda/list view default. Day view as alt. No week/month grid. | Single column. Full-width cards. Bottom sheet for details. |
| **640-1024px (tablet)** | 3-day view default. Week view as alt. | Two column possible. Side panel for details. |
| **> 1024px (desktop)** | Week view default. All views available. | Multi-column. Side panel for details. Click-to-expand. |

### 4.2 Mobile-Specific Patterns

**Calendar on mobile:**
- **Default to agenda/list view** (scrollable list of upcoming items) - NOT a calendar grid
- Calendar grid on mobile is notoriously difficult to use (tiny cells, hard to tap)
- Offer a "mini calendar" at the top for date navigation (collapsed by default, expand to select date)
- Swipe left/right to change days
- Pull-to-refresh for latest data

**Booking flow on mobile:**
- Full-screen steps (one step fills the viewport)
- Bottom-anchored "Next" button (always visible, no scrolling to find it)
- Time slots as full-width buttons in a vertical list (not a grid)
- Sticky header showing progress: "Step 2 of 3: Pick a Time"

**Service provider mobile experience:**
- "Today" view as default (most relevant)
- Swipe-actions on booking cards: swipe right to confirm, swipe left to see options
- Floating action button for quick-add (new booking, block time)
- Bottom navigation: Calendar | Bookings | Team | Reports

### 4.3 Bottom Sheet Pattern for Details

On mobile, booking details should appear as a **bottom sheet** (slides up from bottom) rather than navigating to a new page. This keeps calendar context visible.

```
┌──────────────────────┐
│ Calendar (dimmed)     │
│                       │
│                       │
├───────────────────────┤  ← drag handle
│ ▔▔▔                   │
│ AC Repair             │
│ Bob Johnson           │
│ 10:00am - 11:30am     │
│ 123 Main St           │
│                       │
│ [Confirm] [Decline]   │
│ [More Options]        │
└───────────────────────┘
```

---

## 5. Visual Design System

### 5.1 Booking Status Badge Component

```
Tailwind pattern (existing Badge component style):
- Container: inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-medium
- REQUESTED: bg-amber-50 text-amber-700 border border-amber-200
- CONFIRMED: bg-emerald-50 text-emerald-700 border border-emerald-200
- IN_PROGRESS: bg-blue-50 text-blue-700 border border-blue-200
- COMPLETED: bg-gray-50 text-gray-600 border border-gray-200
- CANCELLED: bg-red-50 text-red-700 border border-red-200 line-through
- NO_SHOW: bg-orange-50 text-orange-700 border border-orange-200
```

Each badge includes a small icon prefix (8x8 or 12x12) for colorblind safety.

### 5.2 Calendar Card Design

**Booking card in calendar grid:**
```
Container: rounded-md px-2 py-1.5 text-xs leading-tight cursor-pointer
           hover:shadow-md transition-shadow
           border-l-3 (thick left border in status color)

Layout:
┌──────────────────┐
│ 10:00 - 11:30    │  ← time in font-medium
│ AC Repair        │  ← service in font-semibold, truncate
│ B. Johnson       │  ← customer name, truncated
│ 🟢 Confirmed     │  ← status mini-badge
└──────────────────┘
```

Use `border-l-4` with status color for the left accent bar. This provides status indication even without reading text.

### 5.3 Typography in Dense Calendar Views

- **Time labels:** `text-xs font-mono text-gray-500` (monospace keeps column alignment)
- **Booking title:** `text-sm font-semibold truncate` (service name)
- **Booking detail:** `text-xs text-gray-600 truncate` (customer, location)
- **Day headers:** `text-sm font-semibold text-gray-900 uppercase tracking-wider`
- **Month/date numbers:** `text-base font-medium` for current month, `text-gray-400` for adjacent months
- **Today indicator:** `bg-blue-600 text-white rounded-full` on the date number

### 5.4 Spacing & Density

Calendar views need to be information-dense but scannable:
- Minimum row height in week view: 48px (for touch targets)
- Gap between booking cards: 2px (`gap-0.5`)
- Calendar day cell padding: 4px (`p-1`)
- Time gutter width: 60px on desktop, 48px on mobile
- Overflow indicator when too many bookings in a cell: "+2 more" link

---

## 6. Micro-Interactions & Feedback

### 6.1 Loading States

| Context | Pattern |
|---------|---------|
| **Available slots loading** | Skeleton grid: 6 placeholder rectangles (pulse animation) in the slot area. Keep calendar visible. |
| **Booking being created** | Button changes to spinner + "Booking..." text. Disable all other inputs. |
| **Calendar data loading** | Skeleton calendar grid with pulsing placeholder cards. Show time labels immediately (they're static). |
| **Confirmation page** | Brief success animation (checkmark draws in) before showing details. |

### 6.2 Success Feedback

- **Booking created:** Green checkmark animation (300ms) → confetti-style subtle particle effect (optional, tasteful) → confirmation details fade in
- **Booking confirmed (provider):** Card smoothly transitions from amber to green, moves from "Pending" to "Upcoming" section
- **Booking completed:** Satisfaction prompt slides in from bottom

### 6.3 Transition Patterns

- **Step transitions in booking wizard:** Slide left (forward) / slide right (back) - 200ms ease-in-out
- **Calendar view switching:** Crossfade between views - 150ms
- **Detail panel open:** Slide from right (desktop) or bottom sheet slide up (mobile) - 250ms
- **Modal open/close:** Fade backdrop + scale-in content - 200ms
- **Time slot selection:** Immediate visual feedback (selected state) - no delay

### 6.4 Confirmation Patterns

| Action | Pattern | Why |
|--------|---------|-----|
| **Book appointment** | Inline confirmation on same page (Step 3 submit → success view) | Don't lose context |
| **Cancel booking** | Confirmation modal: "Cancel this booking? [Reason dropdown] [Keep Booking] [Yes, Cancel]" | Destructive, needs friction |
| **Confirm booking (provider)** | Inline with toast: Button → spinner → green toast "Booking confirmed" | Quick action, shouldn't slow down |
| **Decline booking** | Modal with required reason | Affects customer, need explanation |
| **Delete time-off block** | Inline with undo toast: "Time off removed. [Undo]" (5s window) | Low-risk, allow quick undo |
| **Reschedule** | Navigate to time picker → confirm new time → success | Multi-step, needs new selection |

---

## 7. Competitive Analysis Insights

### 7.1 What to Borrow from the Best

**From Calendly:**
- The elegance of showing only available times (never show unavailable slots)
- Clean, minimal step count (Calendly books in 3 clicks max)
- Timezone-aware display with automatic detection

**From HouseCall Pro:**
- Drag-and-drop calendar is beloved by field service providers
- "Find a time" feature that ranks slots by drive time efficiency
- Color-coded booking statuses visible at a glance on calendar
- The dispatch board showing all technicians side-by-side

**From Acuity Scheduling:**
- Robust offering configuration (duration, buffer, pricing, intake forms)
- Real-time sync that prevents double-booking
- Client self-service portal for managing their own appointments

**From Square Appointments:**
- Seamless payment integration at booking time
- Simple mobile experience for small business owners
- Auto-reminders that reduce no-shows by 30-40%

### 7.2 Where Projulous Can Differentiate

The key differentiator is **PJ (AI assistant) as a booking concierge**. No major competitor has a conversational AI that:
- Understands natural language time preferences ("sometime next week, mornings preferred")
- Proactively suggests maintenance based on appliance/service history
- Compares multiple providers and recommends based on rating + price + availability
- Handles the entire flow conversationally without touching a calendar UI

This should be positioned as the **premium booking experience**, with the traditional calendar wizard as the fallback.

### 7.3 Anti-Patterns Observed in Competitors

- **Too many options upfront:** Some platforms show 20+ service types before any booking context
- **Calendar-only on mobile:** Doesn't work well; agenda view is better
- **No confirmation number:** Some platforms rely on email only - risky if email is delayed
- **Hidden rescheduling:** Making it hard to change appointments leads to no-shows instead
- **Slow loading calendars:** Availability calculations that take 3+ seconds feel broken

---

## 8. Common Pitfalls to Avoid

### 8.1 Design Pitfalls

1. **Showing unavailable times** - Only show slots that can be booked. Grayed-out slots clutter the interface and frustrate users. Exception: show dates (not specific times) as unavailable on the calendar to give context.

2. **Forcing mobile users into a week/month grid** - Calendar grids are unusable on small screens. Default to agenda view on mobile.

3. **Using color as the sole status indicator** - ~8% of men have color vision deficiency. Always pair color with icon + text.

4. **Overloading the calendar** - Too many overlapping visual elements (bookings, travel buffers, time-off, manual entries) makes the calendar unreadable. Use filtering and progressive disclosure.

5. **Making cancellation hard** - If users can't easily cancel/reschedule, they simply no-show. This is worse for everyone.

### 8.2 Flow Pitfalls

6. **Not pre-filling known data** - If we know the customer's address, pre-select it. If coming from a conversation with PJ, carry the context through.

7. **Requiring login before showing availability** - Let users see available times before requiring authentication. Capture login at the confirmation step.

8. **Multi-page flows for simple actions** - Confirming a booking (provider) should be one click + optional note, not a multi-step process.

9. **Missing "next available" shortcut** - When browsing an empty week, users need a quick way to jump to the next date with availability.

10. **No undo for destructive actions** - Cancellations and time-off deletions should offer an undo window (5-10 seconds toast).

### 8.3 Technical Pitfalls

11. **Stale availability data** - If a user spends 5 minutes on Step 2, re-validate the selected slot before creating the booking. Show a graceful fallback if it's been taken.

12. **Timezone confusion** - Always display times in the user's local timezone. Show timezone label explicitly: "10:00 AM EST". Let providers set their operating timezone.

13. **Slow slot generation** - Availability calculation should return in <500ms. Consider caching or pre-computing available slots for popular date ranges.

14. **Missing optimistic UI** - When a provider clicks "Confirm", update the UI immediately (optimistic) and roll back if the API call fails. Don't make them wait for a spinner.

---

*This document should be referenced alongside the main SCHEDULING_FEATURE_PLAN.md during implementation. UX recommendations apply to both web (projulous-web) and mobile (projulous-mobile) implementations.*
