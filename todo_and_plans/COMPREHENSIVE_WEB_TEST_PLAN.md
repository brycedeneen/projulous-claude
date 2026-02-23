# Comprehensive Web Application Test Plan

**Date:** 2026-02-22
**Application:** Projulous Web (localhost:3000)
**Personas:** Anonymous, Customer, Super Admin
**Scope:** Web only (all routes, features, interactions)

---

## Table of Contents

1. [Anonymous User Tests](#1-anonymous-user-tests)
2. [Customer User Tests](#2-customer-user-tests)
3. [Super Admin User Tests](#3-super-admin-user-tests)
4. [Cross-Cutting Tests](#4-cross-cutting-tests)

---

## 1. Anonymous User Tests

### 1.1 Home Page (`/`)

| # | Scenario | Steps | Expected Result |
|---|----------|-------|-----------------|
| A-001 | Home page loads | Navigate to `/` | Hero section with AI search bar, service cards, project showcase visible |
| A-002 | AI search input | Type a project description in the search bar | Text appears in input field |
| A-003 | AI search submit | Type a query and click "Go" | Redirects to conversation/AI flow or prompts login |
| A-004 | Voice input button | Click "Voice Input" button | Microphone activates or prompts browser permission |
| A-005 | AI Model selector | Click "AI Model" button | Model options displayed |
| A-006 | Service category cards | Click "Plumbing" card | Navigates to `/services/plumbing` |
| A-007 | Service category cards | Click "Electrical" card | Navigates to `/services/electrical` |
| A-008 | Service category cards | Click "Air Conditioning" card | Navigates to `/services/hvac` |
| A-009 | Browse all services link | Click "Browse all services" | Navigates to `/services` |
| A-010 | Project showcase cards | Click a project card (e.g., "BD Remodeling") | Navigates to `/projects/:projectSlug` |
| A-011 | "Check out recent projects" button | Click the button | Navigates to `/projects` |
| A-012 | Share an idea FAB | Click "Share an idea" floating button | Opens idea submission modal or redirects |
| A-013 | Footer links | Click Home, Contact, Terms, Privacy | Each navigates to correct page |
| A-014 | Social links | Click Instagram, Facebook | Opens social media (currently `#` placeholders) |

### 1.2 Authentication Pages

| # | Scenario | Steps | Expected Result |
|---|----------|-------|-----------------|
| A-020 | Login page loads | Navigate to `/auth/login` | Login form with email, password, submit button, OAuth buttons |
| A-021 | Login with valid credentials | Enter valid email/password, submit | Redirects to home or role-specific home |
| A-022 | Login with invalid credentials | Enter wrong password, submit | Error message displayed |
| A-023 | Login with empty fields | Submit empty form | Validation errors shown |
| A-024 | Login - forgot password link | Click "Forgot password?" | Navigates to `/auth/forgot-password` |
| A-025 | Login - register link | Click "Create account" / register link | Navigates to `/auth/register` |
| A-026 | Google OAuth login | Click Google OAuth button | Redirects to Google login, then back via `/auth/oauth-callback` |
| A-027 | Register page loads | Navigate to `/auth/register` | Registration form with name, email, password fields |
| A-028 | Register with valid data | Fill all fields correctly, submit | Account created, confirmation email sent |
| A-029 | Register with existing email | Use already registered email | Error: email already exists |
| A-030 | Register password complexity | Enter weak password | Validation error showing complexity requirements |
| A-031 | Register with mismatched passwords | Enter different confirm password | Validation error |
| A-032 | Forgot password page | Navigate to `/auth/forgot-password` | Email input form |
| A-033 | Forgot password submit | Enter valid email, submit | Success message about reset email sent |
| A-034 | Confirm registration | Navigate to `/auth/confirm-registration` with valid token | Account verified successfully |
| A-035 | Confirm reset password | Navigate to `/auth/confirm-reset-password` with valid token | Password reset form |
| A-036 | Unauthorized page | Navigate to `/auth/unauthorized` | 403 error page with appropriate message |

### 1.3 Help Center (Public) (`/help-center`)

| # | Scenario | Steps | Expected Result |
|---|----------|-------|-----------------|
| A-040 | Help center loads | Navigate to `/help-center` | Search bar, popular links, category tabs, browse categories, popular articles |
| A-041 | Search articles | Type in search bar (e.g., "project") | Search results filtered |
| A-042 | Popular article links | Click "Using PJ, Your AI Assistant" | Navigates to article page |
| A-043 | Audience tabs | Click "For Customers" / "For Service Providers" | Filters categories by audience |
| A-044 | Category cards | Click "Getting Started" category | Filters to show articles in that category |
| A-045 | Popular articles section | Click any article link | Navigates to `/help-center/articles/:slug` |
| A-046 | Ideas & Feature Requests link | Click the Ideas card | Navigates to `/help-center/ideas` |
| A-047 | Create a Ticket link | Click "Create a Ticket" | Navigates to `/help-center/contact` |
| A-048 | Email Support link | Click "Email Support" | Navigates to `/help-center/contact` |
| A-049 | Help article page loads | Navigate to `/help-center/articles/:slug` | Article content, title, breadcrumbs displayed |
| A-050 | Help center contact page | Navigate to `/help-center/contact` | Contact/ticket submission form |
| A-051 | Submit contact form | Fill form and submit | Ticket created confirmation |
| A-052 | Ideas board page | Navigate to `/help-center/ideas` | List of community ideas |
| A-053 | Idea detail page | Click an idea | Navigates to `/help-center/ideas/:ideaId` with details |

### 1.4 Services Pages

| # | Scenario | Steps | Expected Result |
|---|----------|-------|-----------------|
| A-060 | Browse all services | Navigate to `/services` | Grid of 55+ service categories with names and "View providers" links |
| A-061 | Service type landing page | Navigate to `/services/plumbing` | Hero with heading, ZIP search, trust badges, provider stats, featured providers section, filters, FAQ |
| A-062 | ZIP code search | Enter ZIP code, click "Search Providers" | Provider results filtered by location |
| A-063 | Sort providers | Change sort dropdown (Top Rated, Most Reviews, etc.) | Results re-ordered |
| A-064 | Filter by minimum rating | Select 4.5+ rating filter, click Apply | Results filtered |
| A-065 | Filter by saved only | Toggle "Saved Only" checkbox | Shows only saved providers (if logged in) |
| A-066 | Provider card click | Click a provider card | Navigates to `/services/:vendorType/provider/:id` |
| A-067 | FAQ section interaction | Click FAQ accordion items | Expand/collapse FAQ answers |
| A-068 | "Get Free Quotes" CTA | Click CTA button | Navigates to home page AI search |
| A-069 | All service categories load | Navigate to each of the 55+ service type pages | Each page loads with correct heading and content |

### 1.5 Project Showcase

| # | Scenario | Steps | Expected Result |
|---|----------|-------|-----------------|
| A-070 | Showcase page loads | Navigate to `/projects` | Search bar, category filter buttons, sort dropdown, project grid |
| A-071 | Search projects | Type search query | Results filtered |
| A-072 | Filter by category | Click "Kitchen", "Bathroom", "Electrical", etc. | Results filtered to category |
| A-073 | Sort projects | Change sort to "Most Popular" or "Highest Rated" | Results re-ordered |
| A-074 | Project story page | Navigate to `/projects/:projectSlug` | Full project story with images, provider info, details |

### 1.6 Legal Pages

| # | Scenario | Steps | Expected Result |
|---|----------|-------|-----------------|
| A-080 | Terms of Service | Navigate to `/legal/terms-of-service` | ToS content loads |
| A-081 | Privacy Policy | Navigate to `/legal/privacy-policy` | Privacy policy content loads |

### 1.7 Service Provider Public Pages

| # | Scenario | Steps | Expected Result |
|---|----------|-------|-----------------|
| A-090 | Why Join page | Navigate to `/service-providers/why-join` | SP recruitment content |
| A-091 | SP Join page | Navigate to `/service-providers/join` | SP signup form (standalone, no sidebar) |
| A-092 | SP Claim Business | Navigate to `/sp/claim` | Claim business form (standalone, no sidebar) |
| A-093 | Invite Accept | Navigate to `/invite/:token` | Team invite acceptance page |
| A-094 | SP Detail page | Navigate to `/services/provider/:id` | SP profile with offerings, reviews, certifications |

### 1.8 Anonymous Access Control

| # | Scenario | Steps | Expected Result |
|---|----------|-------|-----------------|
| A-100 | Access customer routes | Navigate to `/customers/projects` | Redirected to `/auth/login` |
| A-101 | Access admin routes | Navigate to `/admin/users` | Redirected to `/auth/login` |
| A-102 | Access SP routes | Navigate to `/service-providers/dashboard` | Redirected to `/auth/login` |
| A-103 | Access settings | Navigate to `/settings` | Redirected to `/auth/login` |
| A-104 | Access notifications | Navigate to `/notifications` | Redirected to `/auth/login` |

---

## 2. Customer User Tests

**Login:** brycedeneen@gmail.com / P@ssword1!

### 2.1 Navigation & Sidebar

| # | Scenario | Steps | Expected Result |
|---|----------|-------|-----------------|
| C-001 | Sidebar shows customer items | Log in as customer | Sidebar shows: Home, My Projects, My Places, My Appliances, Maintenance, Help Center, My Tickets, Ideas |
| C-002 | No admin section | Check sidebar | Admin section NOT visible |
| C-003 | Become SP link | Check sidebar footer | "Become Service Provider" link visible |
| C-004 | Notification badge | Check notification icon | Badge shows unread count |
| C-005 | User email in sidebar | Check sidebar footer | Customer email displayed |
| C-006 | Logout link | Click email/logout link | Redirected to login page, session cleared |
| C-007 | Sidebar toggle | Click "Close sidebar" button | Sidebar collapses |
| C-008 | Recent projects | If customer has projects, check sidebar | Up to 5 recent projects shown |

### 2.2 Projects (`/customers/projects`)

| # | Scenario | Steps | Expected Result |
|---|----------|-------|-----------------|
| C-010 | Projects list - empty state | Navigate with no projects | "No projects yet" message with "Add Project" CTA |
| C-011 | Projects list - with data | Navigate with existing projects | Project cards displayed |
| C-012 | Create project | Click "Add Project", fill form, submit | New project appears in list |
| C-013 | Create project - validation | Submit empty form | Validation errors shown |
| C-014 | Edit project | Click Edit on a project, modify fields, save | Project updated |
| C-015 | Delete project | Click Delete, confirm in dialog | Project removed from list |
| C-016 | Delete project - cancel | Click Delete, cancel dialog | Project still visible |
| C-017 | Project detail page | Click a project card | Navigate to `/customers/projects/:projectId` |
| C-018 | Project detail - phases | View phases section on detail page | Phases listed with statuses |
| C-019 | Project detail - notes | Add/view notes | Notes CRUD works |
| C-020 | Project detail - budget | View/edit budget section | Budget info displayed |
| C-021 | Project detail - invite SP | Click invite SP button | Invite modal opens |
| C-022 | Project detail - add SP | Add service provider to project | SP added, visible on project |
| C-023 | Project detail - remove SP | Remove SP from project | SP removed |
| C-024 | Project detail - status change | Change project status | Status updated |
| C-025 | Project detail - place info | View place info on project | Place details visible |

### 2.3 Appliances (`/customers/appliances`)

| # | Scenario | Steps | Expected Result |
|---|----------|-------|-----------------|
| C-030 | Appliances list loads | Navigate to appliances | List of appliance cards with image, name, type, status, description, model |
| C-031 | Search appliances | Type in search bar | Results filtered by name |
| C-032 | Sort appliances | Change sort (A-Z, Z-A, Newest, Oldest) | List re-sorted |
| C-033 | Filter by type | Select type from dropdown (28+ types) | Results filtered |
| C-034 | Total count | Check count indicator | Shows correct number (e.g., "5 total") |
| C-035 | Create appliance | Click "Add Appliance", fill form, submit | New appliance card appears |
| C-036 | Create appliance - all fields | Fill name, type, manufacturer, model, serial, description, place, status | All saved correctly |
| C-037 | Edit appliance | Click "Edit" on a card, modify, save | Appliance updated |
| C-038 | Delete appliance | Click "Delete", confirm | Appliance removed |
| C-039 | Appliance detail page | Click appliance card | Navigate to `/customers/appliances/:id` |
| C-040 | Appliance detail - service records | View service history on detail | Service records displayed |
| C-041 | Appliance detail - add service record | Add a service record | Record saved |
| C-042 | Appliance detail - maintenance reminders | View maintenance section | Reminders listed |
| C-043 | Appliance detail - add maintenance reminder | Add a reminder with template or custom | Reminder created |
| C-044 | Appliance detail - complete maintenance | Mark maintenance as done | Log entry created, next due date updated |
| C-045 | Photo extraction | Upload appliance photo | AI extracts make/model/details |
| C-046 | Photo extraction - review | Review extracted data | Can accept/modify extracted fields |
| C-047 | Appliance with photo | Appliance has uploaded photo | Photo displayed on card and detail |

### 2.4 Places (`/customers/places`)

| # | Scenario | Steps | Expected Result |
|---|----------|-------|-----------------|
| C-050 | Places list loads | Navigate to places | Place cards with name, type, address |
| C-051 | Search places | Type in search bar | Results filtered by name |
| C-052 | Sort places | Change sort dropdown | Results re-sorted |
| C-053 | Filter by type | Select type (Primary Home, Secondary, Vacation, Business, Rental, Other) | Results filtered |
| C-054 | Total count | Check count | Correct number shown |
| C-055 | Create place | Click "Add Place", fill form, submit | New place card appears |
| C-056 | Create place - Google address | Use Google address lookup during creation | Address auto-filled |
| C-057 | Edit place | Click "Edit", modify fields, save | Place updated |
| C-058 | Delete place | Click "Delete", confirm | Place removed |
| C-059 | Place detail page | Click a place card | Navigate to `/customers/places/:id` |

### 2.5 Maintenance (`/customers/maintenance`)

| # | Scenario | Steps | Expected Result |
|---|----------|-------|-----------------|
| C-060 | Maintenance page loads | Navigate to maintenance | Stats cards (Overdue, Due Soon, On Track), filters, reminder list |
| C-061 | Filter by appliance | Select specific appliance from dropdown | Reminders filtered |
| C-062 | Filter by status | Select Overdue/Due Soon/On Track | Reminders filtered |
| C-063 | Stats cards | Click stat cards | Filters to that status |
| C-064 | Empty state | No reminders | "No maintenance reminders yet" message |
| C-065 | Reminder detail | Click a reminder | Expanded view with details |
| C-066 | Complete maintenance from list | Mark reminder as done from overview | Logs updated |

### 2.6 Billing (`/customers/billing`)

| # | Scenario | Steps | Expected Result |
|---|----------|-------|-----------------|
| C-070 | Billing page loads | Navigate to billing | Billing/payment information displayed |

### 2.7 Support Tickets (`/customers/tickets`)

| # | Scenario | Steps | Expected Result |
|---|----------|-------|-----------------|
| C-075 | Tickets list loads | Navigate to tickets | List of customer's tickets |
| C-076 | Create ticket | Click create button, fill form, submit | Ticket created |
| C-077 | Ticket detail | Click a ticket | Navigate to detail with messages/status |

### 2.8 Settings (`/settings`)

| # | Scenario | Steps | Expected Result |
|---|----------|-------|-----------------|
| C-080 | Settings page loads | Navigate to settings | Profile, Password, Notification Preferences, Appearance, Language, API Keys sections |
| C-081 | Update profile - name | Change name, click save | Name updated, success message |
| C-082 | Update profile - email | Change email, click save | Email updated (may require verification) |
| C-083 | Change password | Enter current + new + confirm, submit | Password changed |
| C-084 | Change password - wrong current | Enter wrong current password | Error message |
| C-085 | Change password - complexity | Enter weak new password | Validation error |
| C-086 | Change password - mismatch | Mismatched confirm | Validation error |
| C-087 | Notification preferences - push toggle | Toggle push notifications switch | Preference saved |
| C-088 | Notification preferences - email toggle | Toggle email notifications switch | Preference saved |
| C-089 | Notification preferences - categories | Toggle individual categories (Projects, Appliances, Places, SP, Certifications, Support, Team, Schedule, Billing) | Each preference saved |
| C-090 | Appearance - dark mode | Click Dark | Theme changes to dark |
| C-091 | Appearance - light mode | Click Light | Theme changes to light |
| C-092 | Appearance - system mode | Click System | Follows OS preference |
| C-093 | Language - English | Click English | UI language changes |
| C-094 | Language - Spanish | Click Espanol | UI text changes to Spanish |
| C-095 | Language - French | Click Francais | UI text changes to French |
| C-096 | API Keys - create | Click "Create API key" | API key generated and displayed |

### 2.9 Notifications (`/notifications`)

| # | Scenario | Steps | Expected Result |
|---|----------|-------|-----------------|
| C-100 | Notifications page loads | Navigate to notifications | Notification list with unread count, filters, pagination |
| C-101 | Unread count | Check unread badge | Matches sidebar badge |
| C-102 | Mark all as read | Click "Mark all as read" | All notifications marked read, count resets |
| C-103 | Filter - All | Click "All" tab | All notifications shown |
| C-104 | Filter - Unread | Click "Unread" tab | Only unread notifications shown |
| C-105 | Mark individual as read | Click "Mark as read" on a notification | Notification marked read |
| C-106 | Delete notification | Click "Delete" on a notification | Notification removed |
| C-107 | Pagination | Navigate through pages | Pages load correctly |
| C-108 | Real-time updates (SSE) | Trigger an event in another tab | New notification appears without page refresh |

### 2.10 Customer Access Control

| # | Scenario | Steps | Expected Result |
|---|----------|-------|-----------------|
| C-110 | Access admin routes | Navigate to `/admin/users` | Redirected to unauthorized or role home |
| C-111 | Access SP routes | Navigate to `/service-providers/dashboard` | Redirected to unauthorized or role home |
| C-112 | Access other customer's data | Try to access another customer's project/appliance by ID manipulation | 403 or redirect |

### 2.11 AI Conversation Flow

| # | Scenario | Steps | Expected Result |
|---|----------|-------|-----------------|
| C-120 | Start conversation | Enter project description on home page, click Go | AI conversation begins |
| C-121 | Clarification flow | AI asks clarifying questions | Options presented to user |
| C-122 | Problem description | AI prompts for problem description | Text input available |
| C-123 | Urgency/timeline | AI prompts for urgency | Timeline options displayed |
| C-124 | Provider comparison Q&A | Ask questions about providers | AI responds with provider data |
| C-125 | Multi-language AI | Switch language, start conversation | AI responds in selected language |

---

## 3. Super Admin User Tests

**Login:** bryce@redbricksoftware.com / P@ssword1!

### 3.1 Navigation & Sidebar

| # | Scenario | Steps | Expected Result |
|---|----------|-------|-----------------|
| SA-001 | Sidebar shows all sections | Log in as super admin | General nav + Admin section + SP section visible |
| SA-002 | Admin section items | Check admin nav | SP Verification, SP Management, Help Center Admin, Support Tickets, User Management, Role Management, Vendor Pages, Ideas Management, Audit Logs, AI Logs |
| SA-003 | SP section items | Check SP nav | Dashboard, My Offerings, Team Management, Billing, Tickets |
| SA-004 | Notification badge | Check badge | Shows unread count (99+) |
| SA-005 | Admin default redirect | After login, check redirect | Goes to role home (`/admin/users` or home) |

### 3.2 User Management (`/admin/users`)

| # | Scenario | Steps | Expected Result |
|---|----------|-------|-----------------|
| SA-010 | Page loads | Navigate to admin users | Stats cards (Total, Verified, Unverified, Deleted, Super Admins), user table |
| SA-011 | Search users | Type in search by name/email | Results filtered |
| SA-012 | Filter by role | Select "Customer" from role dropdown | Only customers shown |
| SA-013 | Filter by role - all options | Test all role filters (All, Super Admin, SP, Customer) | Each filter works |
| SA-014 | Filter by verified | Select "Verified" / "Unverified" | Results filtered |
| SA-015 | Filter by status | Select "Active" / "Deleted" / "All" | Results filtered |
| SA-016 | Stats cards | Click stat cards | Filters table accordingly |
| SA-017 | Tabs - Users/Roles | Click "Roles & Permissions" tab | Switches to role management |
| SA-018 | User table columns | Check table | User, Roles, Verified, Auth, Created, Status, Actions columns |
| SA-019 | View user detail | Click user row or "View" action | Navigate to `/admin/users/:userId` |
| SA-020 | More actions menu | Click "More actions" button on a user | Dropdown with additional actions |
| SA-021 | User detail page | Navigate to user detail | Full user info, roles, edit capabilities |
| SA-022 | Edit user | Modify user fields on detail page | Changes saved |

### 3.3 Role Management (`/admin/roles`)

| # | Scenario | Steps | Expected Result |
|---|----------|-------|-----------------|
| SA-030 | Page loads | Navigate to role management | Stats (Total, System, Custom), role table |
| SA-031 | Create role | Click "Create role", fill form, submit | New role appears in table |
| SA-032 | Role table columns | Check table | Name, Description, Type, Permissions, Members, Actions |
| SA-033 | View role detail | Click role name | Navigate to `/admin/roles/:roleId` |
| SA-034 | Role detail - permissions | View permissions on detail page | All permissions listed with toggles |
| SA-035 | Edit role permissions | Toggle permissions, save | Permissions updated |
| SA-036 | System roles | Check system roles (Customer, SP, Super Admin) | Marked as "System" type |

### 3.4 Support Tickets Admin (`/admin/support-tickets`)

| # | Scenario | Steps | Expected Result |
|---|----------|-------|-----------------|
| SA-040 | Page loads | Navigate to admin tickets | Stats (Open, In Progress, Resolved, Closed), search, filters, ticket table |
| SA-041 | Search tickets | Type search query | Results filtered |
| SA-042 | Filter by status | Select status (All, Open, In Progress, Resolved, Closed) | Results filtered |
| SA-043 | Filter by category | Select category (Account, Billing, Projects, Provider Disputes, Technical, Feature Request, Service Followup, Other) | Results filtered |
| SA-044 | Filter by priority | Select priority (Low, Normal, High, Urgent) | Results filtered |
| SA-045 | Stats cards | Click stat cards | Filter table |
| SA-046 | Ticket table columns | Check table | Subject, Category, Status, Priority, Submitter, Created, Actions |
| SA-047 | View ticket detail | Click ticket subject or view button | Ticket detail page with messages, status management |
| SA-048 | Update ticket status | Change ticket status on detail page | Status updated |
| SA-049 | Respond to ticket | Add admin response to ticket | Response saved and visible |

### 3.5 Vendor Pages Admin (`/admin/vendor-pages`)

| # | Scenario | Steps | Expected Result |
|---|----------|-------|-----------------|
| SA-050 | Page loads | Navigate to vendor pages admin | "Recalculate All Stats" button, "New Vendor Page" link, search, filter, table |
| SA-051 | Search vendor pages | Type search by name/slug | Results filtered |
| SA-052 | Filter by status | Select Draft/Published | Results filtered |
| SA-053 | Vendor page table | Check table | Name, Slug, Offering Type, Rank, Status, Actions columns |
| SA-054 | Create vendor page | Click "New Vendor Page" | Navigate to editor at `/admin/vendor-pages/new` |
| SA-055 | Vendor page editor - create | Fill editor form, save | New page created, visible in table |
| SA-056 | Edit vendor page | Click "Edit" on a page | Navigate to editor at `/admin/vendor-pages/:id/edit` |
| SA-057 | Vendor page editor - edit | Modify fields (heading, description, FAQ, status), save | Changes saved |
| SA-058 | Delete vendor page | Click "Delete", confirm | Page removed from table |
| SA-059 | Recalculate stats | Click "Recalculate All Stats" | Stats recalculated for all vendor pages |
| SA-060 | Vendor page slug format | Create page with name | Slug auto-generated correctly |

### 3.6 Help Center Admin (`/admin/help-center`)

| # | Scenario | Steps | Expected Result |
|---|----------|-------|-----------------|
| SA-065 | Page loads | Navigate to help center admin | Tabs (Articles, Categories, FAQs), search, filters, article table |
| SA-066 | Articles tab | Click Articles tab | List of articles with Title, Category, Status, Audience, Updated, Actions |
| SA-067 | Search articles | Type search query | Results filtered |
| SA-068 | Filter by status | Select Draft/Published/Archived | Results filtered |
| SA-069 | Filter by audience | Select Customer/SP/All | Results filtered |
| SA-070 | Create article | Click "New Article" | Navigate to article editor |
| SA-071 | Article editor | Fill title, content, category, status, audience, save | Article created |
| SA-072 | Edit article | Click "Edit" on an article | Navigate to editor with pre-filled data |
| SA-073 | Delete article | Click "Delete", confirm | Article removed |
| SA-074 | Categories tab | Click Categories tab | Category management UI |
| SA-075 | FAQs tab | Click FAQs tab | FAQ management UI |
| SA-076 | Create/edit/delete category | CRUD operations on categories | All operations work |
| SA-077 | Create/edit/delete FAQ | CRUD operations on FAQs | All operations work |

### 3.7 SP Verification (`/admin/service-provider-review`)

| # | Scenario | Steps | Expected Result |
|---|----------|-------|-----------------|
| SA-080 | Page loads | Navigate to SP verification | Dashboard with pending SP reviews |
| SA-081 | Review SP | Click on a pending SP | Detail page with SP info, certifications |
| SA-082 | Approve SP | Click approve on review detail | SP approved, status updated |
| SA-083 | Reject SP | Click reject on review detail | SP rejected with reason |

### 3.8 SP Management (`/admin/service-providers`)

| # | Scenario | Steps | Expected Result |
|---|----------|-------|-----------------|
| SA-085 | Page loads | Navigate to SP management | List of all service providers |
| SA-086 | Search/filter SPs | Use search and filters | Results filtered |
| SA-087 | Edit SP | Select and modify SP details | Changes saved |
| SA-088 | Delete SP | Delete a service provider | SP removed |

### 3.9 Ideas Management (`/admin/ideas`)

| # | Scenario | Steps | Expected Result |
|---|----------|-------|-----------------|
| SA-090 | Page loads | Navigate to ideas management | List of all ideas/feedback |
| SA-091 | Idea detail | Click an idea | Detail page with votes, comments |
| SA-092 | Update idea status | Change status | Status updated |

### 3.10 Audit Logs (`/admin/audit-logs`)

| # | Scenario | Steps | Expected Result |
|---|----------|-------|-----------------|
| SA-095 | Page loads | Navigate to audit logs | PJ Analyze button, filters, log table with pagination |
| SA-096 | Filter by entity name | Type entity name (e.g., "CustomerProject") | Results filtered |
| SA-097 | Filter by entity ID | Paste an entity ID | Results filtered |
| SA-098 | Filter by user | Type user email/name | Results filtered |
| SA-099 | Filter by event type | Type event type (e.g., "PROJECT_CREATE") | Results filtered |
| SA-100 | Filter by action | Select CREATE/UPDATE/DELETE/RESTORE/STATUS_CHANGE | Results filtered |
| SA-101 | Filter by date range | Set date from/to | Results filtered to range |
| SA-102 | Log table columns | Check table | Date, User, Action, Entity, Entity ID, Event Type, Details |
| SA-103 | Pagination | Navigate through pages | Pages load correctly (7410+ entries, 371+ pages) |
| SA-104 | PJ Analyze button | Click PJ Analyze | AI analysis feature activates |
| SA-105 | Combine filters | Apply multiple filters simultaneously | Results correctly intersected |

### 3.11 AI Logs (`/admin/ai-logs`)

| # | Scenario | Steps | Expected Result |
|---|----------|-------|-----------------|
| SA-110 | Page loads | Navigate to AI logs | Log table with AI interaction details |
| SA-111 | Filter logs | Apply filters | Results filtered |
| SA-112 | Log detail | View individual AI interaction log | Full request/response details |

### 3.12 SP Claims Admin (`/admin/sp-claims`)

| # | Scenario | Steps | Expected Result |
|---|----------|-------|-----------------|
| SA-115 | Page loads | Navigate to SP claims | List of business claim requests |
| SA-116 | Review claim | Click a claim | Detail with verification info |

### 3.13 Admin Access Control

| # | Scenario | Steps | Expected Result |
|---|----------|-------|-----------------|
| SA-120 | Permission-gated routes | Attempt to access route without required permission | Redirected to `/auth/unauthorized` |
| SA-121 | Super admin sees all admin routes | Navigate through all admin sidebar links | All pages accessible |
| SA-122 | Admin also has customer features | Navigate to `/customers/projects` | Customer features accessible |

---

## 4. Cross-Cutting Tests

### 4.1 Responsive Design

| # | Scenario | Steps | Expected Result |
|---|----------|-------|-----------------|
| X-001 | Desktop layout | View at 1920x1080 | Full sidebar, proper layout |
| X-002 | Tablet layout | View at 768x1024 | Sidebar collapsible, responsive grid |
| X-003 | Mobile layout | View at 375x667 | Hamburger menu, stacked layout |
| X-004 | Sidebar collapse | Toggle sidebar on smaller screens | Content area expands |

### 4.2 Internationalization (i18n)

| # | Scenario | Steps | Expected Result |
|---|----------|-------|-----------------|
| X-010 | Language picker in sidebar | Click language button in sidebar | Language modal/selector opens |
| X-011 | Switch to Spanish | Select Espanol | All UI text changes to Spanish |
| X-012 | Switch to French | Select Francais | All UI text changes to French |
| X-013 | Switch back to English | Select English | All UI text changes back to English |
| X-014 | Language persists across navigation | Change language, navigate to other pages | Language setting maintained |
| X-015 | Language saved to profile | Change language, logout, login | Language setting preserved |
| X-016 | Form labels in selected language | Switch language, open a form | All labels translated |
| X-017 | Error messages translated | Trigger validation in non-English | Errors in selected language |
| X-018 | Help center in language | Switch to Spanish, visit help center | Articles/content in Spanish |

### 4.3 Theme / Appearance

| # | Scenario | Steps | Expected Result |
|---|----------|-------|-----------------|
| X-020 | Dark mode | Select Dark in settings | UI switches to dark theme |
| X-021 | Light mode | Select Light in settings | UI switches to light theme |
| X-022 | System mode | Select System, toggle OS dark mode | UI follows OS setting |
| X-023 | Theme persists | Change theme, navigate | Theme maintained across pages |
| X-024 | Theme persists across sessions | Change theme, logout, login | Theme setting preserved |

### 4.4 Navigation & Layout

| # | Scenario | Steps | Expected Result |
|---|----------|-------|-----------------|
| X-030 | Footer present on all pages | Visit multiple pages | Footer with Home, Contact, Terms, Privacy links on every page |
| X-031 | Sidebar navigation works | Click each sidebar item | Navigates to correct page |
| X-032 | Active sidebar item highlighted | Navigate to a page | Corresponding sidebar item highlighted |
| X-033 | Share an idea FAB | Check multiple pages | FAB button present on all pages |
| X-034 | Browser back/forward | Navigate forward, click back | Correct previous page loads |
| X-035 | Deep linking | Directly enter URL for a deep page | Page loads correctly |
| X-036 | 404 handling | Navigate to non-existent route | Appropriate error page |

### 4.5 Authentication & Session

| # | Scenario | Steps | Expected Result |
|---|----------|-------|-----------------|
| X-040 | Token expiry | Wait for token to expire | Redirected to login, or token refreshed |
| X-041 | Refresh token rotation | Allow access token to expire | New access token obtained via refresh |
| X-042 | Logout clears session | Click logout | Tokens cleared, redirected to login |
| X-043 | Multiple tabs | Open app in two tabs, logout in one | Other tab handles session loss gracefully |
| X-044 | Policy acceptance modal | First login after policy update | Policy acceptance modal shown on auth routes |

### 4.6 Performance & Loading

| # | Scenario | Steps | Expected Result |
|---|----------|-------|-----------------|
| X-050 | Page load times | Navigate to each major page | Pages load within acceptable time |
| X-051 | Large data pagination | View audit logs (7400+ entries) | Pagination works, no freezing |
| X-052 | Large notification list | View notifications (19000+ entries) | Loads with pagination, no crash |
| X-053 | Service browse page | Load 55+ service categories | All render without lag |

### 4.7 Error Handling

| # | Scenario | Steps | Expected Result |
|---|----------|-------|-----------------|
| X-060 | API error on page load | Backend returns error | Graceful error message, not blank page |
| X-061 | Network disconnection | Lose network during action | Error notification shown |
| X-062 | Form submission errors | Backend validation fails | Error messages displayed on form |
| X-063 | 404 for missing entity | Navigate to deleted project/appliance by ID | Proper error or redirect |

### 4.8 Security

| # | Scenario | Steps | Expected Result |
|---|----------|-------|-----------------|
| X-070 | CSRF protection | Inspect requests | Tokens included where required |
| X-071 | XSS prevention | Enter `<script>` in text fields | Input sanitized, no script execution |
| X-072 | Authorization bypass | Manipulate API calls to access other user's data | 403 Forbidden response |
| X-073 | Rate limiting | Rapid-fire login attempts | Rate limited after threshold |
| X-074 | Password complexity | Try to set simple password | Rejected with complexity requirements |
| X-075 | SQL injection | Enter SQL in search/filter fields | No SQL execution, proper escaping |

### 4.9 Accessibility

| # | Scenario | Steps | Expected Result |
|---|----------|-------|-----------------|
| X-080 | Keyboard navigation | Tab through page elements | All interactive elements focusable |
| X-081 | Screen reader labels | Check buttons/inputs for ARIA labels | Properly labeled |
| X-082 | Color contrast | Check text against backgrounds | Meets WCAG AA minimum |
| X-083 | Focus indicators | Tab through elements | Visible focus rings |
| X-084 | Cursor styles | Hover over clickable elements | `cursor-pointer` on all clickable elements |

### 4.10 Real-Time Features

| # | Scenario | Steps | Expected Result |
|---|----------|-------|-----------------|
| X-090 | SSE notification connection | Login and check | SSE connection established |
| X-091 | Real-time notifications | Trigger event (e.g., create ticket) | Notification appears in real-time |
| X-092 | Notification badge update | Receive new notification | Badge count increments |

---

## Test Summary

| Section | Test Count |
|---------|-----------|
| Anonymous User | ~50 tests |
| Customer User | ~70 tests |
| Super Admin User | ~55 tests |
| Cross-Cutting | ~45 tests |
| **Total** | **~220 tests** |

## Execution Notes

- **Anonymous tests:** Run in incognito/logged-out browser
- **Customer tests:** Login as `brycedeneen@gmail.com` / `P@ssword1!`
- **Super Admin tests:** Login as `bryce@redbricksoftware.com` / `P@ssword1!`
- **Cross-cutting tests:** Run across all personas where applicable
- Service Provider persona is deferred for now
- Each persona session requires a separate login/logout cycle
