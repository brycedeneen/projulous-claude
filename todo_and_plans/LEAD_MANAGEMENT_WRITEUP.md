# Lead Management System - How It Works

## Overview

The Lead Management System tracks the lifecycle of every customer-to-service-provider referral made through Projulous. It captures when a customer is connected with a service provider, follows up to learn the outcome, and calculates referral fees. The system operates across three surfaces: the backend API, the web admin dashboard, and the Redbrick mobile admin app.

---

## How Leads Are Created

Leads are created automatically through two triggers. No manual action is needed.

### Trigger 1: AI Find Service Flow

When a customer uses the AI chat and takes an explicit action to engage with recommended providers:

1. Customer chats with PJ (the AI assistant), describes their problem, answers clarification questions
2. PJ recommends matching service providers — **no leads are created at this point**
3. Customer reviews the provider cards and decides to take action (e.g., clicks "Create Project" or "Contact Vendor")
4. The `handleSelectProviders` method fires, creating a `CustomerProject` and adding the selected providers to it
5. **One Lead is created per selected provider** (fire-and-forget, non-blocking)
   - Source: `AI_FIND_SERVICE`
   - Message: the conversation name / problem description
   - Linked to: the conversation + customer project
6. Each Lead gets a unique `actionToken` (UUID) with a 30-day expiry for later customer follow-up

**What happens next depends on whether the SP has an email address:**

- **SP has email** → Lead status is set to `SENT_EMAIL`. An email is sent to the SP using the `quote-request` template with the customer's name, problem description, contact info, and referral fee notice.
- **SP has no email** → Lead status is set to `SENT_ADMIN_CALL`. All super admins receive an email and in-app notification saying "Lead Requires Phone Call" with the SP's phone number and the customer's problem. An admin then needs to call the SP manually.

### Trigger 2: Quote Request Creation

When a quote request is created (through the quote request flow), a decoupled event listener creates a Lead:

1. The `QUOTE_REQUEST_CREATE` event fires
2. The Lead event controller picks it up and calls `createLeadFromQuoteRequest`
3. A Lead is created with source `QUOTE_REQUEST`, linked to the quote request entity
4. Guest fields (name, email, phone) are carried over from the quote request
5. Same SP email logic applies for notifications

---

## Automated Follow-Up (CRON Jobs)

### 7-Day Follow-Up Email (Daily at 11 AM UTC)

Seven days after a lead is created, if the customer hasn't already been followed up with:

1. CRON finds leads in `SENT_EMAIL` or `ADMIN_CALLED` status where `followUpSentAt` is null and created >= 7 days ago
2. Leads are grouped by conversation/customer so each customer gets one email even if multiple SPs were selected
3. The email asks: *"A week ago we connected you with service providers for your project. Which provider did you go with?"*
4. Each SP is listed with an "I chose this provider" button
5. Clicking a button hits `GET /v1/public/lead-select/:token` which:
   - Marks that Lead as `CUSTOMER_SELECTED`
   - Sets `customerSelectedAt` timestamp
   - Redirects the customer to the follow-up web page (`/lead-followup?token=...`)
6. `followUpSentAt` is set on all leads in the group so they won't get a duplicate email
7. Registered customers also receive an in-app push notification

### 30-Day Expiration (Daily at 12 PM UTC)

Leads that are still in non-terminal statuses after 30 days are automatically set to `EXPIRED`. Terminal statuses that are excluded from expiration: `CUSTOMER_SELECTED`, `INVOICE_UPLOADED`, `FEE_COLLECTED`, `COMPLETED`, `EXPIRED`, `SP_DECLINED`.

---

## Customer Follow-Up Page (Public Web)

**URL:** `/lead-followup?token=<actionToken>`

This is a public page — no login required. The customer arrives here after clicking an SP button in the follow-up email.

1. The page reads the `token` from the URL
2. Fetches lead info from `GET /v1/public/lead-followup/:token` (returns the lead + all related leads for the same conversation)
3. Shows the SP name that was selected (pre-filled from the email click)
4. Asks: *"Approximately how much did/will the work cost?"* with a dollar amount input
5. Customer submits → `POST /v1/public/lead-followup/:token` with `{ customerEstimate }`
6. The estimate is saved, the referral fee is calculated (`estimate * referralFeePercent / 100`)
7. Success screen: *"Thank you! Your feedback helps us improve our service."*
8. If the token is invalid or expired, a friendly error is shown

---

## Referral Fee Calculation

Each lead has a `referralFeePercent` field (default 10%). When a `customerEstimate` or `spReportedAmount` is provided:

```
calculatedFeeAmount = amount * (referralFeePercent / 100)
```

### Discrepancy Audit

When both the customer estimate and SP-reported amount exist, the system checks for discrepancies:

- **>30% difference**: Sets `auditFlag = true` and records the discrepancy in `auditNotes` (e.g., "Customer: $500, SP: $800, diff: 37.5%")
- **>50% difference**: Additionally logs a warning for admin review

Audit flags are visible on both the web admin detail page and the mobile detail screen.

---

## Lead Status Lifecycle

```
                    ┌─ SP has email ──→ SENT_EMAIL
PENDING (initial) ──┤
                    └─ No SP email ──→ SENT_ADMIN_CALL
                                            │
                                      ADMIN_CALLING
                                       │         │
                                ADMIN_CALLED   ADMIN_NO_ANSWER
                                       │
                                   SENT_EMAIL
                                       │
                                   SP_ACCEPTED ──→ SP_QUOTED
                                       │
                              CUSTOMER_SELECTED
                                       │
                              INVOICE_UPLOADED
                                       │
                                FEE_COLLECTED
                                       │
                                  COMPLETED

Side paths:
  Any non-terminal ──(30 days)──→ EXPIRED
  Any ──(SP declines)──→ SP_DECLINED
```

Note: `PENDING` is the initial status but is immediately changed to either `SENT_EMAIL` or `SENT_ADMIN_CALL` during lead creation. A lead only stays in `PENDING` if created via `MANUAL_ADMIN` source.

---

## Admin Web Dashboard

**URL:** `/admin/leads`
**Access:** Requires `LEAD_ADMIN`, `LEAD_READ`, or `LEAD_MODIFY` permission (or `SUPER_ADMIN`)

### List Page

- **Stat cards** across the top showing counts for key statuses:
  - Pending (amber)
  - Needs Admin Call (red) — combines `SENT_ADMIN_CALL` + `ADMIN_NO_ANSWER`
  - Sent (blue) — `SENT_EMAIL`
  - Customer Selected (green)
  - Completed (green)
- Clicking a stat card filters the table to that status
- **Filters:** Search bar (searches message, guest name, guest email, SP name), status dropdown, source dropdown
- **Table columns:** SP Name, Customer, Source (badge), Status (color-coded badge), Created date, Actions (eye icon)
- **Pagination:** 20 per page with Previous/Next controls
- Clicking a row navigates to the detail page

### Status Badge Colors

| Color | Statuses |
|-------|----------|
| Red | `SENT_ADMIN_CALL`, `ADMIN_NO_ANSWER` |
| Amber | `PENDING`, `ADMIN_CALLING` |
| Blue | `SENT_EMAIL`, `SP_QUOTED`, `ADMIN_CALLED`, `SP_ACCEPTED`, `INVOICE_UPLOADED` |
| Green | `CUSTOMER_SELECTED`, `COMPLETED`, `FEE_COLLECTED` |
| Gray | `EXPIRED`, `SP_DECLINED` |

### Source Badge Colors

| Color | Source |
|-------|--------|
| Blue | `AI_FIND_SERVICE` |
| Green | `QUOTE_REQUEST` |
| Purple | `MANUAL_ADMIN` |

### Detail Page (`/admin/leads/:leadId`)

- **Back button** to return to the list
- **Lead Info card:** SP name, customer name (registered or guest), source, all timestamps (created, updated, follow-up sent, customer selected, SP responded)
- **Message section:** The full problem description / chat summary
- **Referral Fee section:** Fee percentage, customer estimate, SP reported amount, calculated fee amount. If `auditFlag` is true, shows a red warning with the audit notes.
- **Related entities:** Links to the conversation, customer project, and quote request (if they exist)
- **Invoice section:** Shows the uploaded invoice filename (if present)
- **Admin controls:**
  - Status dropdown (all 14 statuses)
  - Admin notes textarea (free-form text)
  - Save button → calls `PUT /v1/leads/:leadId`
  - Success/error feedback after save

---

## Redbrick Mobile Admin App

The Leads tab is the 5th tab in the bottom nav of the Redbrick Software internal admin app.

### Leads Tab (`/leads`)

- **Status filter chips** in a horizontal scroll: All, Pending, Needs Call, Sent, Customer Selected, Completed, Expired
- **Lead cards** showing: SP name, customer name, status badge (colored), source badge, created date, audit flag indicator
- **Pull-to-refresh** to reload
- **Search** with debounced input
- Tap a lead → navigates to detail screen

### Lead Detail (`/leads/:leadId`)

- **Lead info sections:** Status (editable picker), source, SP name, customer info, message
- **Referral fee section:** Fee %, estimates, calculated fee, audit flag warning
- **Timeline:** All timestamps displayed
- **Admin notes:** Editable text input
- **Save button** appears when changes are made → `PUT /v1/leads/:leadId`

---

## Data Flow Summary

```
Customer uses AI chat
         │
    Views recommended providers
    (no leads created yet)
         │
    Clicks "Create Project" /
    "Contact Vendor" button
         │
    ┌────┴─────────────────┐
    │  Lead created per SP  │
    │  (fire-and-forget)    │
    └────┬─────────────────┘
         │
    SP has email?
    ├── Yes → Email SP, status = SENT_EMAIL
    └── No  → Notify admins, status = SENT_ADMIN_CALL
                    │
              Admin calls SP manually
              Updates status via dashboard
                    │
         ┌──────────┴──────────┐
     7 days pass               │
         │                     │
  CRON sends follow-up    Admin manages
  email to customer       status in dashboard
         │
  Customer clicks
  "I chose this provider"
         │
  Redirected to /lead-followup
  Enters cost estimate
         │
  Fee calculated
  auditFlag checked
         │
  Admin reviews in dashboard
  Updates status through lifecycle
  until COMPLETED / FEE_COLLECTED
```

---

## API Endpoints

### Admin (auth required)

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/v1/leads` | List leads with filters (status, source, search, skip, take) |
| `GET` | `/v1/leads/:leadId` | Get single lead with relations |
| `POST` | `/v1/leads` | Create lead manually |
| `PUT` | `/v1/leads/:leadId` | Update lead (status, adminNotes, fee fields) |
| `DELETE` | `/v1/leads/:leadId` | Delete lead |

### GraphQL (admin, auth required)

| Query | Description |
|-------|-------------|
| `getLeads(status, source, search, skip, take)` | Paginated list with relations |
| `getLead(leadId)` | Single lead with all relations |

### Public (no auth, token-based, rate-limited)

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/v1/public/lead-select/:token` | One-click SP selection from email → redirects to follow-up page |
| `GET` | `/v1/public/lead-followup/:token` | Get lead info for follow-up page |
| `POST` | `/v1/public/lead-followup/:token` | Submit customer estimate |

---

## Permissions

| Permission | Purpose |
|------------|---------|
| `LEAD_CREATE` | Create new leads |
| `LEAD_READ` | View leads |
| `LEAD_MODIFY` | Update lead status and details |
| `LEAD_DELETE` | Delete leads |
| `LEAD_ADMIN` | Full lead management access |

All are admin-only. `SUPER_ADMIN` bypasses permission checks entirely.
