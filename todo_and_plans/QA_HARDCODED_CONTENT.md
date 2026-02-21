# Pre-Launch Hardcoded / Placeholder Content Report

**Date**: 2026-02-14
**Scope**: Full web app sweep across all personas

---

## Summary

| Category | Count | Launch Blocking? |
|----------|-------|-----------------|
| ~~Placeholder Data~~ | ~~1~~ | RESOLVED |
| ~~E2E Test Data Pollution~~ | ~~3~~ | RESOLVED |
| Missing Content | 4 | REVIEW |
| Stub Pages | 2 | NO |

---

## Placeholder Data (Launch Blocking)

### ~~1. Fake Phone Number: "1-800-555-1234"~~ — RESOLVED
- Phone Support card commented out until real phone number is available.

---

## ~~E2E Test Data Pollution~~ — RESOLVED

E2E cleanup SQL executed. All E2E test data removed from prod DB.

---

## Missing Content (Review for Launch)

These areas are empty or have no content. Decide whether to seed content before launch or accept empty states.

### 5. Help Center "Popular Articles" -- Empty
- **Page**: `/help-center`
- **Current Display**: "No articles found."
- **Action**: Seed popular/starter articles or accept empty state

### 6. Help Center "Browse by Category" -- Empty
- **Page**: `/help-center`
- **Current Display**: No categories visible
- **Action**: Create help center categories or accept empty state

### 7. Project Showcase -- Empty
- **Page**: `/projects`
- **Current Display**: "No projects found"
- **Action**: Seed sample/showcase projects or accept empty state

### 8. Vendor Landing Pages -- Not Implemented
- **Pages**: `/services/plumber`, `/services/electrician`, etc.
- **Current Behavior**: Silently redirects to home. Home page service cards (Plumbing, Electrical, HVAC) are not clickable links.
- **Action**: Decide if vendor pages are needed for launch. If not, ensure service cards don't imply they're clickable.

---

## Stub Pages (Not Launch Blocking)

These pages exist but have minimal/no functionality. Acceptable for launch if hidden from navigation.

### 9. Customer Billing (`/customers/billing`)
- **Display**: Shows "Invoices & Billing" title, otherwise empty
- **Status**: Hidden from sidebar navigation -- acceptable

### ~~10. SP Billing (`/service-providers/billing`)~~ — RESOLVED
- Hidden from sidebar navigation.

---

## Test Data in User Content (Low Priority)

### 11. Appliance Model "TEST-MODEL-123"
- **Page**: `/customers/appliances` (Washing machine)
- **Issue**: Likely user-entered test data, not hardcoded
- **Action**: Clean up if this is a demo/production database

---

## Recommendations

### ~~P0 -- Must Fix Before Launch~~ — ALL RESOLVED
1. ~~Replace or remove fake phone number (1-800-555-1234)~~ — RESOLVED
2. ~~Delete all E2E test data from database~~ — RESOLVED

### P1 -- Should Fix Before Launch
3. Seed Help Center with real articles and categories
4. ~~Hide "Become a Service Provider" from SP/Admin users~~ — RESOLVED
5. ~~Hide SP Billing from sidebar until implemented~~ — RESOLVED

### P2 -- Nice to Have
6. Seed project showcase with sample projects
7. Clean up test appliance data
8. Implement or hide vendor landing page links
