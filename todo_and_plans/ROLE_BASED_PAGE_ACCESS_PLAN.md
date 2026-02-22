# Role-Based Page Access Plan

## Problem Statement

Currently, any authenticated user can access any page by typing the URL directly. While the sidebar already hides links based on user type and the backend properly rejects unauthorized write operations, users can still **view** pages they shouldn't access (e.g., a Customer can view `/admin/vendor-pages` or `/service-providers/dashboard`).

## Current State

| Layer | Protection | Gap |
|-------|-----------|-----|
| Sidebar | Hides links by role | Users can type URLs directly |
| `authGuard.layout.tsx` | Checks JWT not expired | No role checking |
| `adminGuard.layout.tsx` | Checks specific permissions per admin route | Only covers `/admin/*` |
| Backend API | Returns 403 for unauthorized operations | Pages still render (empty/broken state) |

## Design Decisions

### 1. Hardcoded Static Config (User Preference)
Route-to-role mapping will be a static TypeScript configuration file, not database-driven. This is appropriate because:
- Route structure changes infrequently
- Changes require code deployment anyway (new routes = new code)
- Simpler to maintain, test, and reason about
- No additional API calls needed at runtime

### 2. Unified Config Drives Both Guards AND Navigation
A single `routeAccessConfig.ts` will be the source of truth for:
- **Route guards** — which roles can access which pages
- **Sidebar navigation** — which links to show (replacing current hardcoded sidebar logic)

This eliminates the current duplication where the sidebar has its own permission-checking logic separate from the guard layouts.

### 3. Multi-Role Support
Users can have **multiple roles simultaneously** (e.g., a user who is both a Customer and a Service Provider, or a Customer who is also a Super Admin). The guard grants access if **any** of the user's roles is permitted for the route.

### 4. Extend Existing Guard Pattern
Follow the proven `adminGuard.layout.tsx` pattern (ROUTE_PERMISSION_MAP) but at the role level, wrapping entire route groups.

---

## Route-to-Role Mapping

### Complete Access Matrix

| Route | Anonymous | CUSTOMER | SERVICE_PROVIDER | SUPER_ADMIN |
|-------|-----------|----------|------------------|-------------|
| **Public Routes** | | | | |
| `/` (home) | Yes | Yes | Yes | Yes |
| `/help-center`, `/help-center/*` | Yes | Yes | Yes | Yes |
| `/services`, `/services/*` | Yes | Yes | Yes | Yes |
| `/projects`, `/projects/*` | Yes | Yes | Yes | Yes |
| `/legal/*` | Yes | Yes | Yes | Yes |
| `/service-providers/why-join` | Yes | Yes | Yes | Yes |
| `/invite/:token` | Yes | Yes | Yes | Yes |
| **Standalone Routes (no nav)** | | | | |
| `/service-providers/join` | Yes | Yes | Yes | Yes |
| `/sp/claim` | Yes | Yes | Yes | Yes |
| `/sp/onboarding` | No | No | Yes | Yes |
| **Auth Routes** | | | | |
| `/auth/*` | Yes | Yes | Yes | Yes |
| **Shared Authenticated Routes** | | | | |
| `/settings` | No | Yes | Yes | Yes |
| `/notifications` | No | Yes | Yes | Yes |
| **Customer Routes** | | | | |
| `/customers/projects` | No | Yes | No | Yes |
| `/customers/projects/:projectId` | No | Yes | No | Yes |
| `/customers/appliances` | No | Yes | No | Yes |
| `/customers/appliances/:id` | No | Yes | No | Yes |
| `/customers/places` | No | Yes | No | Yes |
| `/customers/places/:id` | No | Yes | No | Yes |
| `/customers/maintenance` | No | Yes | No | Yes |
| `/customers/billing` | No | Yes | No | Yes |
| `/customers/tickets` | No | Yes | No | Yes |
| `/customers/tickets/:id` | No | Yes | No | Yes |
| **Service Provider Routes** | | | | |
| `/service-providers/dashboard` | No | No | Yes | Yes |
| `/service-providers/offerings` | No | No | Yes | Yes |
| `/service-providers/billing` | No | No | Yes | Yes |
| `/service-providers/team` | No | No | Yes | Yes |
| `/service-providers/team/:userId` | No | No | Yes | Yes |
| `/service-providers/certification` | No | No | Yes | Yes |
| `/service-providers/tickets` | No | No | Yes | Yes |
| `/service-providers/tickets/:id` | No | No | Yes | Yes |
| **Admin Routes** | | | | |
| `/admin/*` (all admin routes) | No | No | No | Yes* |

\* Admin routes are additionally gated by fine-grained permissions via `adminGuard.layout.tsx`

**Multi-role example:** A user with both CUSTOMER and SERVICE_PROVIDER roles can access both `/customers/projects` and `/service-providers/dashboard`.

### Route Config Structure

```typescript
// app/shared/config/routeAccessConfig.ts

import { RoleENUM } from 'projulous-shared-dto-node/dist/shared/enums/role.enum';

export type RouteAccessRule = {
  /** Route path prefix to match against (startsWith) */
  path: string;
  /** Roles allowed to access. SUPER_ADMIN always bypasses. Empty array = SUPER_ADMIN only. */
  allowedRoles: RoleENUM[];
};

/**
 * Centralized route access configuration.
 * Checked top-to-bottom, first match wins.
 * SUPER_ADMIN always has access (implicit bypass).
 * Routes not listed here are accessible to all authenticated users.
 */
export const ROUTE_ACCESS_CONFIG: RouteAccessRule[] = [
  // Customer-only routes
  { path: '/customers', allowedRoles: [RoleENUM.CUSTOMER] },

  // Service Provider-only authenticated routes
  { path: '/service-providers/dashboard', allowedRoles: [RoleENUM.SERVICE_PROVIDER] },
  { path: '/service-providers/billing', allowedRoles: [RoleENUM.SERVICE_PROVIDER] },
  { path: '/service-providers/team', allowedRoles: [RoleENUM.SERVICE_PROVIDER] },
  { path: '/service-providers/certification', allowedRoles: [RoleENUM.SERVICE_PROVIDER] },
  { path: '/service-providers/offerings', allowedRoles: [RoleENUM.SERVICE_PROVIDER] },
  { path: '/service-providers/tickets', allowedRoles: [RoleENUM.SERVICE_PROVIDER] },

  // SP Onboarding (standalone route, SP-only)
  { path: '/sp/onboarding', allowedRoles: [RoleENUM.SERVICE_PROVIDER] },

  // Admin routes — SUPER_ADMIN only (empty array = no regular role gets access)
  { path: '/admin', allowedRoles: [] },
];

// NOTE: These routes are NOT listed and are therefore accessible to all authenticated users:
//   /settings, /notifications
// These routes are public (outside authGuard) and not checked:
//   /, /help-center/*, /services/*, /projects/*, /legal/*,
//   /service-providers/why-join, /service-providers/join, /sp/claim,
//   /auth/*, /invite/:token
```

---

## Role Detection: Multi-Role Approach

```typescript
// app/shared/utils/roleUtils.ts

import { PermissionENUM } from 'projulous-shared-dto-node/dist/shared/enums/permission.enum';
import { RoleENUM } from 'projulous-shared-dto-node/dist/shared/enums/role.enum';
import { LocalStoreService } from '../../dataAccess/storage.service';
import { ROUTE_ACCESS_CONFIG } from '../config/routeAccessConfig';

/**
 * Returns ALL roles the current user has.
 * A user can have multiple roles simultaneously.
 */
export function getCurrentUserRoles(): RoleENUM[] {
  const store = LocalStoreService.getInstance();
  const permissions = store.getPermissions();
  const roles: RoleENUM[] = [];

  // SUPER_ADMIN: detected via permission
  if (permissions.includes(PermissionENUM.SUPER_ADMIN_SUPER_ADMIN)) {
    roles.push(RoleENUM.SUPER_ADMIN);
  }

  // CUSTOMER: detected via stored customerId
  if (store.getCustomerId()) {
    roles.push(RoleENUM.CUSTOMER);
  }

  // SERVICE_PROVIDER: detected via stored serviceProviderId
  if (store.getServiceProviderId()) {
    roles.push(RoleENUM.SERVICE_PROVIDER);
  }

  return roles;
}

/**
 * Check if the given roles grant access to a specific route path.
 * SUPER_ADMIN always has access.
 * Routes not in config are accessible to all authenticated users.
 */
export function canAccessRoute(pathname: string, roles: RoleENUM[]): boolean {
  // SUPER_ADMIN bypasses all checks
  if (roles.includes(RoleENUM.SUPER_ADMIN)) return true;

  // Find first matching rule (top-to-bottom, first match wins)
  const rule = ROUTE_ACCESS_CONFIG.find(r => pathname.startsWith(r.path));

  // No matching rule = accessible to all authenticated users
  if (!rule) return true;

  // Check if ANY of the user's roles is in the allowed list
  return rule.allowedRoles.some(allowedRole => roles.includes(allowedRole));
}

/**
 * Get the best redirect path for a user based on their roles.
 * Prioritizes: SUPER_ADMIN > SERVICE_PROVIDER > CUSTOMER > login
 */
export function getRoleHomePath(roles: RoleENUM[]): string {
  if (roles.includes(RoleENUM.SUPER_ADMIN)) return '/admin/users';
  if (roles.includes(RoleENUM.SERVICE_PROVIDER)) return '/service-providers/dashboard';
  if (roles.includes(RoleENUM.CUSTOMER)) return '/';
  return '/auth/login';
}
```

---

## Implementation Plan

### Phase 1: Core Infrastructure (New Files)

#### 1a. Create `routeAccessConfig.ts`
**File:** `projulous-web/app/shared/config/routeAccessConfig.ts`
- Route-to-role mapping as shown above
- Export `RouteAccessRule` type and `ROUTE_ACCESS_CONFIG` array

#### 1b. Create `roleUtils.ts`
**File:** `projulous-web/app/shared/utils/roleUtils.ts`
- `getCurrentUserRoles()` — returns `RoleENUM[]` using customerId, serviceProviderId, and permissions
- `canAccessRoute(pathname, roles)` — check if any role grants access to a route
- `getRoleHomePath(roles)` — get best redirect target for a multi-role user

#### 1c. Create `roleGuard.layout.tsx`
**File:** `projulous-web/app/shared/components/roleGuard.layout.tsx`

```typescript
export default function RoleGuardLayout() {
  const location = useLocation();
  const roles = getCurrentUserRoles();

  if (canAccessRoute(location.pathname, roles)) {
    return <Outlet />;
  }

  // Not allowed — redirect to role-appropriate home
  return <Navigate to={getRoleHomePath(roles)} replace />;
}
```

### Phase 2: Route Integration

#### 2a. Update `routes.ts`
Insert `roleGuard.layout.tsx` in the route tree:

```
horizontalNav.layout.tsx
  (public routes - unchanged)
  authGuard.layout.tsx          ← checks "is logged in"
    roleGuard.layout.tsx        ← NEW: checks "can this role see this route"
      (customer routes)
      (service provider routes)
      (shared auth routes: /settings, /notifications)
    adminGuard.layout.tsx       ← keeps existing fine-grained permission checks
      (admin routes)
```

#### 2b. Handle `/sp/onboarding` standalone route
This route is outside the nav layout. Add roleGuard protection inline or wrap it separately in routes.ts since it should be SP-only.

### Phase 3: Unified Navigation

#### 3a. Update `sidebar.tsx` to use `routeAccessConfig.ts`
Replace the current hardcoded permission checks in the sidebar with config-driven logic:

```typescript
// Instead of many individual checks:
const canViewSpTeam = isServiceProvider;
const canViewSpVerification = hasPermission(PermissionENUM.SUPER_ADMIN_SUPER_ADMIN);

// Use unified utility:
const roles = getCurrentUserRoles();
const canAccess = (path: string) => canAccessRoute(path, roles);

// In render:
{canAccess('/customers/projects') && <NavLink to="/customers/projects">My Projects</NavLink>}
{canAccess('/service-providers/dashboard') && <NavLink to="/service-providers/dashboard">Dashboard</NavLink>}
```

**Note:** The admin section of the sidebar should continue using fine-grained permission checks (from `adminGuard.layout.tsx`'s ROUTE_PERMISSION_MAP) since admin routes have per-route permission requirements beyond just the SUPER_ADMIN role.

### Phase 4: Testing

#### 4a. Unit tests for `roleGuard.layout.tsx`
**File:** `projulous-web/app/shared/components/roleGuard.layout.test.tsx`

Test scenarios (following existing `adminGuard.layout.test.tsx` pattern):
- SUPER_ADMIN can access all routes
- CUSTOMER can access `/customers/*`, cannot access `/service-providers/dashboard`
- SERVICE_PROVIDER can access `/service-providers/*`, cannot access `/customers/*`
- **Multi-role: CUSTOMER + SERVICE_PROVIDER can access both `/customers/*` and `/service-providers/*`**
- **Multi-role: CUSTOMER + SUPER_ADMIN can access all routes**
- Routes not in config are accessible to all authenticated users
- Redirect goes to role-appropriate home page

#### 4b. Unit tests for `roleUtils.ts`
- `getCurrentUserRoles()` returns correct roles for each combination of customerId/serviceProviderId/permissions
- `canAccessRoute()` handles single roles, multi-roles, and SUPER_ADMIN bypass
- `getRoleHomePath()` returns correct path for each role combination

#### 4c. Update sidebar tests
- Verify sidebar uses config-driven visibility
- Multi-role users see sections for all their roles

---

## UX Design: Unauthorized Access Behavior

### Silent Redirect
When a user navigates to a route they can't access:

1. **Immediately redirect** to their role-appropriate home page
2. **No error page shown** — the user simply lands on their dashboard/home
3. **Optional toast notification**: "You don't have access to that page" (subtle, non-blocking)

### Rationale
- Users shouldn't encounter these forbidden pages in normal usage (sidebar hides them)
- Direct URL access is typically accidental (bookmark from different account, shared link)
- An error page feels punitive; a silent redirect is more user-friendly
- The existing `/auth/unauthorized` page is reserved for unauthenticated access attempts

### Redirect Targets (Multi-Role Aware)
| User's Roles | Redirect To |
|-------------|------------|
| CUSTOMER only | `/` (home) |
| SERVICE_PROVIDER only | `/service-providers/dashboard` |
| CUSTOMER + SERVICE_PROVIDER | `/service-providers/dashboard` (SP takes priority) |
| SUPER_ADMIN (any combo) | N/A (has access to everything) |
| Not logged in | `/auth/login` (handled by authGuard) |

---

## Files Changed Summary

| File | Action | Description |
|------|--------|-------------|
| `app/shared/config/routeAccessConfig.ts` | **NEW** | Centralized route-to-role mapping |
| `app/shared/utils/roleUtils.ts` | **NEW** | Multi-role detection and access checking utilities |
| `app/shared/components/roleGuard.layout.tsx` | **NEW** | Layout guard component |
| `app/routes.ts` | **MODIFY** | Insert roleGuard layout in route tree |
| `app/nav/sidebar.tsx` | **MODIFY** | Use config-driven navigation visibility |
| `app/shared/components/roleGuard.layout.test.tsx` | **NEW** | Guard tests |
| `app/shared/utils/roleUtils.test.ts` | **NEW** | Utility tests |

**No backend changes needed.** This is purely a frontend feature.
**No shared-dto changes needed.** RoleENUM and PermissionENUM already exist.

---

## Acceptance Criteria

### Single-Role Scenarios
1. **CUSTOMER accessing `/customers/projects`** → Page renders normally
2. **CUSTOMER accessing `/service-providers/dashboard`** → Redirected to `/` (home)
3. **CUSTOMER accessing `/admin/users`** → Redirected to `/` (home)
4. **SERVICE_PROVIDER accessing `/service-providers/dashboard`** → Page renders normally
5. **SERVICE_PROVIDER accessing `/customers/projects`** → Redirected to `/service-providers/dashboard`
6. **SERVICE_PROVIDER accessing `/admin/users`** → Redirected to `/service-providers/dashboard`
7. **SUPER_ADMIN accessing any page** → Always renders normally

### Multi-Role Scenarios
8. **CUSTOMER + SERVICE_PROVIDER accessing `/customers/projects`** → Page renders normally
9. **CUSTOMER + SERVICE_PROVIDER accessing `/service-providers/dashboard`** → Page renders normally
10. **CUSTOMER + SERVICE_PROVIDER accessing `/admin/users`** → Redirected to `/service-providers/dashboard`
11. **CUSTOMER + SUPER_ADMIN accessing any page** → Always renders normally

### General
12. **Unauthenticated user accessing `/customers/projects`** → Redirected to `/auth/login`
13. **Sidebar links match guard rules** — no visible link that the guard would block
14. **Public routes (/help-center, /services, etc.)** → Accessible to all, no change
15. **Shared auth routes (/settings, /notifications)** → Accessible to all authenticated users
16. **`/service-providers/join` and `/sp/claim`** → Accessible to anyone (public)
17. **`/sp/onboarding`** → Only accessible to SERVICE_PROVIDER (and SUPER_ADMIN)

---

## Risks & Considerations

1. **Stale permissions in localStorage**: If a user's role changes server-side, they need to re-login for the new permissions to take effect. This is the existing behavior and acceptable.

2. **Race condition on login**: Permissions and IDs are stored after login. The roleGuard should gracefully handle the case where data hasn't been stored yet (treat as no roles, let authGuard handle redirect to login).

3. **Route matching order**: The `ROUTE_ACCESS_CONFIG` array is checked top-to-bottom, first match wins. Public SP routes like `/service-providers/why-join` are outside the authGuard layout so they won't hit the roleGuard at all. The config only lists specific SP sub-routes that need guarding.

4. **Admin guard interaction**: The `adminGuard.layout.tsx` already handles admin routes well. The roleGuard provides an additional layer blocking non-admins before they reach the adminGuard. Both layers remain for defense in depth.

5. **`/sp/onboarding` is a standalone route**: It's outside the `horizontalNav.layout.tsx` tree, so it needs its own guard wrapping in `routes.ts` or an inline check.
