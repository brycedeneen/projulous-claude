# Full Manual Test Plan - Projulous Web

## Pre-Test Setup

```bash
# Terminal 1 - Backend
cd projulous-svc && npm run start:dev

# Terminal 2 - Frontend
cd projulous-web && npm run dev

# Verify
curl -s http://localhost:8123/v1/healthCheck  # => true
# Open http://localhost:3000
```

## Test Credentials

| Persona | Email | Password |
|---------|-------|----------|
| Customer | brycedeneen@gmail.com | P@ssword1! |
| Service Provider | brycedeneen+ps@gmail.com | P@ssword1! |
| Super Admin | bryce@redbricksoftware.com | P@ssword1! |
| Anonymous | (no login) | - |

---

## Phase 1: Anonymous User (No Login)

### 1.1 Home Page (`/`)
- [ ] Page loads with AI prompt input and feature cards
- [ ] Service category cards display correctly
- [ ] "Find a Service" prompt input is functional
- [ ] Navigation links in header/footer work

### 1.2 Auth Pages
- [ ] `/auth/login` - Login form renders, OAuth buttons visible
- [ ] `/auth/register` - Registration form renders with all fields
- [ ] `/auth/forgot-password` - Forgot password form renders
- [ ] Invalid login shows error message

### 1.3 Help Center (`/help-center`)
- [ ] Help center loads with articles and categories
- [ ] Search/filter by category works
- [ ] Click article navigates to `/help-center/:id`
- [ ] Article detail page renders content correctly
- [ ] `/help-center/contact` - Contact form renders

### 1.4 Public Project Showcase (`/projects`)
- [ ] Project gallery loads with public projects
- [ ] Click project navigates to `/projects/:id`
- [ ] Project story page renders details

### 1.5 Browse Services (`/services`)
- [ ] Service categories page loads
- [ ] Click category navigates to `/services/:slug`
- [ ] Service provider detail page shows profile, offerings

### 1.6 SP Recruitment (`/service-providers/why-join`)
- [ ] Why Join page renders with benefits
- [ ] CTA links to `/service-providers/join`
- [ ] SP registration form renders

### 1.7 Access Control (Anonymous)
- [ ] `/customers/projects` redirects to login
- [ ] `/service-providers/dashboard` redirects to login
- [ ] `/admin/users` redirects to login
- [ ] `/settings` redirects to login
- [ ] `/notifications` redirects to login

---

## Phase 2: Customer Persona

**Login**: brycedeneen@gmail.com / P@ssword1!

### 2.1 Login & Redirect
- [ ] Login succeeds, redirects appropriately
- [ ] Sidebar shows: Start Project, My Projects, My Places, My Appliances, Help Center, My Tickets, Ideas
- [ ] Recent projects section shows in sidebar
- [ ] User name and avatar display in sidebar footer
- [ ] Notification bell shows with unread count

### 2.2 Customer Projects (`/customers/projects`)
- [ ] Projects list loads with all customer projects
- [ ] Create project - click button, fill modal (name, description, type), submit
- [ ] New project appears in list
- [ ] Click project navigates to `/customers/projects/:id`

### 2.3 Project Detail (`/customers/projects/:id`)
- [ ] Project detail page loads with all sections
- [ ] Edit project - update name/description, save, verify persistence
- [ ] Delete project - confirmation modal, confirm, removed from list
- [ ] Place info section displays correctly
- [ ] **Add SP to project** - modal opens, search/filter SPs, add, verify in list
- [ ] **Remove SP from project** - confirmation, verify removed
- [ ] View SPs on project - status, contact info displayed
- [ ] Create ticket from project - modal, fill category/description/priority, submit

### 2.4 Customer Places (`/customers/places`)
- [ ] Places list loads
- [ ] Create place - name, address (Google autocomplete), submit
- [ ] Place appears in list
- [ ] Click place navigates to `/customers/places/:id`
- [ ] Place detail shows address, map, linked appliances
- [ ] Edit place - update fields, save, verify
- [ ] Delete place - confirmation, removed from list

### 2.5 Customer Appliances (`/customers/appliances`)
- [ ] Appliances list loads
- [ ] Create appliance - select type, model, manufacturer, year, assign to place, submit
- [ ] Appliance appears in list
- [ ] Click appliance navigates to `/customers/appliances/:id`

### 2.6 Appliance Detail (`/customers/appliances/:id`)
- [ ] Appliance detail loads with specs
- [ ] Edit appliance - update model, manufacturer, year, notes, save
- [ ] Delete appliance - confirmation, removed from list
- [ ] **Service History** section visible
- [ ] Add service record - date, provider, work done, cost, submit
- [ ] Service record appears in history timeline
- [ ] Location field displays correctly

### 2.7 Customer Tickets (`/customers/tickets`)
- [ ] Tickets list loads
- [ ] Click ticket navigates to `/customers/tickets/:id`
- [ ] Ticket detail shows category, description, status, activity

### 2.8 Customer Billing (`/customers/billing`)
- [ ] Billing page loads
- [ ] Payment information section renders

### 2.9 Notifications (`/notifications`)
- [ ] Notification center loads with tabs (unread/all)
- [ ] Notifications display with correct content
- [ ] Acknowledge single notification - mark as read
- [ ] Acknowledge all - bulk mark as read
- [ ] Bell icon count updates after acknowledgment

### 2.10 Settings (`/settings`)
- [ ] Profile section - name, email displayed correctly
- [ ] Update profile name - save, verify persistence
- [ ] Change password - enter current, new password, confirm, save
- [ ] Language picker - switch to ES, verify UI translates
- [ ] Language picker - switch to FR, verify UI translates
- [ ] Language picker - switch back to EN
- [ ] Theme toggle - switch to Dark mode, verify all elements render
- [ ] Theme toggle - switch to Light mode
- [ ] **Notification preferences** - toggle push/email per category
- [ ] Verify preference changes persist after page reload

### 2.11 Ideas/Feedback (`/help-center/ideas`)
- [ ] Ideas board loads with list of ideas
- [ ] Create idea - title, description, category, submit
- [ ] New idea appears in list
- [ ] Vote on idea - upvote, counter updates
- [ ] Comment on idea - add comment, appears in thread

### 2.12 Customer Access Control
- [ ] `/admin/users` shows unauthorized page
- [ ] `/admin/help-center` shows unauthorized page
- [ ] `/service-providers/dashboard` - verify behavior (should redirect or show unauthorized)

---

## Phase 3: Service Provider Persona

**Login**: brycedeneen+ps@gmail.com / P@ssword1!

### 3.1 Login & Redirect
- [ ] Login succeeds, redirects to `/service-providers/dashboard`
- [ ] Sidebar shows SP section: Dashboard, Team, Billing, Tickets
- [ ] Sidebar also shows customer sections if SP has customer permissions

### 3.2 SP Dashboard (`/service-providers/dashboard`)
- [ ] Dashboard loads with profile card
- [ ] Recent projects section displays
- [ ] Offerings section displays service types
- [ ] Team stats/metrics render

### 3.3 Team Management (`/service-providers/team`)
- [ ] Team members list loads
- [ ] **Invite team member** - enter email, select role (ADMIN/MEMBER), send invite
- [ ] Pending invites section shows invitation
- [ ] Cancel pending invite - remove from list
- [ ] View team member detail (`/service-providers/team/:id`)
- [ ] Change member role - promote to ADMIN or demote to MEMBER
- [ ] Deactivate member - confirmation, removed from active list

### 3.4 SP Billing (`/service-providers/billing`)
- [ ] Billing page loads
- [ ] Payment methods section renders

### 3.5 SP Tickets (`/service-providers/tickets`)
- [ ] Tickets list loads (tickets from customers)
- [ ] Click ticket navigates to `/service-providers/tickets/:id`
- [ ] Ticket detail shows customer info, description, status

### 3.6 SP Notifications & Settings
- [ ] Notifications load and function (same as customer tests 2.9)
- [ ] Settings load with SP-specific profile info
- [ ] Language/theme/notification preferences work (same as 2.10)

### 3.7 SP + Customer Features
- [ ] If SP also has customer role: My Projects, Places, Appliances accessible
- [ ] Verify both sidebars sections visible and functional

### 3.8 SP Access Control
- [ ] `/admin/users` shows unauthorized page
- [ ] `/admin/help-center` shows unauthorized page
- [ ] `/admin/support-tickets` shows unauthorized page

---

## Phase 4: Super Admin Persona

**Login**: bryce@redbricksoftware.com / P@ssword1!

### 4.1 Login & Redirect
- [ ] Login succeeds
- [ ] Sidebar shows admin sections: SP Verification, SP Management, Help Center, Support Tickets, User Management, Vendor Pages, Ideas Management
- [ ] Admin sections are permission-gated (all visible for super admin)

### 4.2 SP Certification Review (`/admin/service-provider-review`)
- [ ] List of SPs pending certification loads
- [ ] Filters/sorting work
- [ ] Click SP opens detail view
- [ ] View SP profile, offerings, verification documents
- [ ] **Approve SP** - status changes to CERTIFIED
- [ ] **Reject SP** - enter reason, status updates
- [ ] **Request more info** - send request, mark awaiting response

### 4.3 SP Management (`/admin/service-providers`)
- [ ] List of all service providers loads
- [ ] Search/filter SPs
- [ ] Click SP to view details
- [ ] Deactivate/suspend SP
- [ ] View SP certification history

### 4.4 Help Center Admin (`/admin/help-center`)
- [ ] Articles list loads
- [ ] **Create article** - title, rich content editor, category, audience, save
- [ ] **Edit article** (`/admin/help-center/articles/edit`) - update content, save
- [ ] **Delete article** - confirmation, removed
- [ ] Categories management (`/admin/help-center/categories`)
- [ ] Create/edit/delete categories
- [ ] FAQ management (`/admin/help-center/faqs`)
- [ ] Create/edit/delete FAQs
- [ ] Verify changes visible on public help center

### 4.5 Vendor Pages (`/admin/vendor-pages`)
- [ ] Vendor pages list loads
- [ ] **Create vendor page** - service category, display name, slug, service types
- [ ] **Edit vendor page** - update details, save
- [ ] Publish/unpublish toggle
- [ ] Verify public page at `/services/:slug` reflects changes

### 4.6 Support Tickets (`/admin/support-tickets`)
- [ ] All support tickets list loads
- [ ] Filters by status, category, priority work
- [ ] Click ticket navigates to `/admin/support-tickets/:id`
- [ ] Ticket detail shows full activity log
- [ ] Respond to ticket - add response, status updates
- [ ] Triage ticket - assign priority, category

### 4.7 User Management (`/admin/users`)
- [ ] Users list loads with search/filter
- [ ] Click user navigates to `/admin/users/:id`
- [ ] User detail shows profile, roles, audit log
- [ ] View user activity history
- [ ] Deactivate user account

### 4.8 Ideas Admin (`/admin/ideas`)
- [ ] Ideas list loads with admin controls
- [ ] Click idea navigates to `/admin/ideas/:id`
- [ ] **Update idea status** - PLANNED/IN_PROGRESS/COMPLETED
- [ ] **Merge ideas** - combine duplicate ideas
- [ ] Admin comment on idea
- [ ] Verify status changes visible on public ideas board

### 4.9 Admin Notifications & Settings
- [ ] Notifications load and function
- [ ] Settings load with admin profile
- [ ] Language/theme/notification preferences work

### 4.10 Admin Access to Customer/SP Features
- [ ] Verify admin does NOT see "My Projects" etc. in sidebar (super admins skip customer section)
- [ ] Verify admin CAN access SP sections if they have SP permissions

---

## Cross-Cutting Tests (Run During Any Persona)

### C.1 Responsive Design
- [ ] Desktop: Sidebar expanded/collapsed toggle works
- [ ] Mobile viewport (375px): Sidebar hidden, hamburger menu works
- [ ] Tablet viewport (768px): Layout adapts correctly
- [ ] All modals are usable on mobile

### C.2 Dark Mode
- [ ] Toggle dark mode in settings
- [ ] All pages render correctly (no invisible text, broken contrast)
- [ ] Forms, modals, cards all styled in dark mode
- [ ] Toggle back to light mode, verify reset

### C.3 i18n / Language
- [ ] Switch to Spanish (ES) - all static text translates
- [ ] Switch to French (FR) - all static text translates
- [ ] Special characters render correctly
- [ ] Date/number formatting updates
- [ ] Switch back to English (EN)

### C.4 Error States
- [ ] Navigate to invalid route - 404 page displays
- [ ] Network error handling (disconnect backend, check frontend behavior)
- [ ] Empty states - no data messages shown appropriately
- [ ] Form validation - required fields show errors
- [ ] Loading spinners appear during async operations

### C.5 Navigation
- [ ] Browser back/forward buttons work correctly
- [ ] Direct URL navigation works for all routes
- [ ] Sidebar active state highlights current page
- [ ] Logo click returns to home

---

## Test Results Log

| Phase | Persona | Tester | Date | Status | Notes |
|-------|---------|--------|------|--------|-------|
| 1 | Anonymous | | | | |
| 2 | Customer | | | | |
| 3 | Service Provider | | | | |
| 4 | Super Admin | | | | |
| C | Cross-Cutting | | | | |
