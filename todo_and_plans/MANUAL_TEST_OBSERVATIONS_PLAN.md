# Manual Test Observations - Improvement Plan

**Date:** 2026-03-15
**Source:** Comprehensive manual testing of all 4 personas (Anonymous, Customer, SP, Super Admin)

## Bugs Fixed (This Session)

| # | Bug | File Changed | Fix |
|---|-----|-------------|-----|
| 1 | Data Privacy page required login | `projulous-web/app/routes.ts` | Moved `/legal/data-privacy` route from inside `authGuard` layout to the public legal routes section |
| 2 | Ideas Management "Invalid Date" chart | `projulous-svc/src/feedback/services/feedbackSubmission.service.ts` | Skip entries with no `createdDate` instead of returning `'unknown'` date string |
| 3 | Spanish translation incomplete on home page | `projulous-web/app/routes/home/home.route.tsx` | Fixed i18n key from `services.${slug}.subtitle` to `services.${slug}.description` |

## Observations to Address

### 1. Maintenance items show "Unknown Appliance"
**Priority:** Low
**Description:** Customer maintenance page shows 2 maintenance reminders linked to "Unknown Appliance". The customer has no appliances, but reminders exist (likely from seed data or test creation).
**Root Cause:** Maintenance reminders exist in the DB without valid appliance references for this user.
**Action:** Investigate the seed data or creation flow. Either:
- Clean up orphaned maintenance reminders in the DB
- Add a null check in the maintenance UI to display "No appliance assigned" instead of "Unknown Appliance" with a broken link
- Ensure create/update flows validate appliance ownership

### 2. Admin route protection inconsistency
**Priority:** Medium
**Description:** When anonymous users access admin routes (e.g., `/admin/users`), they are redirected to `/` (home) instead of `/auth/login` like customer and SP routes.
**Root Cause:** In `routes.ts`, admin routes are wrapped in `roleGuard.layout.tsx` only (not `authGuard.layout.tsx`). The role guard redirects to `getRoleHomePath([])` which returns `/` for users with no roles. Customer/SP routes are inside both `authGuard` + `roleGuard`, so unauthenticated users hit `authGuard` first and go to `/auth/login`.
**Action:** Wrap the admin routes section in `authGuard.layout.tsx` as well:
```
layout('./shared/components/authGuard.layout.tsx', [
  layout('./shared/components/roleGuard.layout.tsx', { id: 'admin-role-guard' }, [
    // admin routes...
  ]),
]),
```

### 3. No visible logout button
**Priority:** Medium
**Description:** Clicking the user email/profile at the bottom of the sidebar does nothing. There is no visible logout button, dropdown, or menu. Users have no way to log out from the web app (other than clearing localStorage).
**Action:** Add an onClick handler to the profile/email element in the sidebar that either:
- Opens a small dropdown menu with "Logout" and "Profile" options
- Or navigates directly to the settings page where a logout button should exist
- The logout action should call `POST /v1/auth/logout` and clear local storage

### 4. No "Create Ticket" button on SP Tickets page
**Priority:** Low
**Description:** The customer tickets page has a "+ Create Ticket" button, but the SP tickets page only has stats cards, search, and filters - no way to create a new ticket. SPs must use the Help Center contact form instead.
**Action:** Either:
- Add a "+ Create Ticket" button to the SP tickets page (matching customer UI)
- Or add a "Need help? Contact Support" link that routes to `/help-center/contact`
- This is a UX consistency issue, not a blocker

### 5. "Browse all services" card description not translated
**Priority:** Low
**Description:** On the home page in Spanish mode, the "Ver todos los servicios" card still shows "Explore all available home services" in English. The other 3 service cards now translate correctly after the bug fix.
**Root Cause:** The "Browse all services" card is hardcoded in the home.route.tsx JSX (it's a static `<Link>` element, not rendered via the dynamic vendor pages loop that uses i18n).
**Action:** Wrap the description text in the static "Browse all services" card with `t('home.browseAllServicesDescription')` and add the translation key to all 3 language files (en.json, es.json, fr.json).

## Implementation Priority

1. **Admin route protection** (Medium) - Security-adjacent, quick fix
2. **Logout button** (Medium) - Critical UX gap
3. **Maintenance "Unknown Appliance"** (Low) - Data quality
4. **SP Create Ticket button** (Low) - UX consistency
5. **Browse all services translation** (Low) - i18n completeness
