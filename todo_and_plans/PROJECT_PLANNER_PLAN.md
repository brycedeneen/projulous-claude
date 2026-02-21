# PJ AI Project Planner — Feature Plan

## Status Summary (Updated 2026-02-19)

| Sprint | Description | Status |
|--------|------------|--------|
| Sprint 1 | Shared DTOs & Entities | COMPLETE |
| Sprint 2 | Backend Services & APIs | COMPLETE |
| Sprint 3 | AI Engine | COMPLETE |
| Sprint 4 | Web Frontend — Plan & Phases | COMPLETE |
| Sprint 5 | Web Frontend — Budget & Collaboration | COMPLETE |
| Sprint 6 | Mobile Frontend | COMPLETE |
| Sprint 7 | Notifications & Polish | NOT STARTED |
| Phase 6 | Collaborator Auth & Access | NOT STARTED |

### What Was Built

**Shared DTOs (Sprint 1):**
- 5 new enums: ProjectStatusENUM, ProjectPhaseStatusENUM, CollaboratorRoleENUM, CollaboratorInviteStatusENUM, ProjectNoteTypeENUM
- 3 new entities: ProjectPhase, ProjectCollaborator, ProjectNote
- Modified: CustomerProject (8 new fields, 3 OneToMany relations), QuoteRequest (phase/project links)
- Modified: ConversationTypeENUM (PROJECT_PLANNING), ConversationStatusENUM (4 planning statuses)
- 13 new permissions added to PermissionENUM, 8 new event types

**Backend (Sprints 2-3):**
- ProjectPhaseService: CRUD + reorder + bulkCreate
- ProjectCollaboratorService: CRUD + invite (crypto token, 7-day expiry) + accept + access validation
- ProjectNoteService: CRUD with optional phase filter
- REST controllers + GraphQL resolvers + event controllers for all three
- ProjectPlannerService: AI orchestration with 6 prompt configs, Zod schemas, state machine flow
- ChatService modified for complex project intent detection and PLANNING_* status routing
- Unit tests for collaborator (19 tests) and note (10 tests) services

**Web Frontend (Sprints 4-5):**
- Project detail restructured into 5-tab layout (Overview, Plan, Budget, Team, Quotes)
- 12 new components: PhaseStatusBadge, PhaseCard, PhaseList, PhaseDetailModal, BudgetOverview, BudgetBreakdown, ActualCostModal, CollaboratorList, InviteCollaboratorModal, ProjectNoteList, ProjectNoteForm, ProjectPlannerChat
- Data access layers for phases, collaborators, notes
- ~150 i18n keys added (EN/ES/FR)

**Mobile Frontend (Sprint 6):**
- Tab-based project detail with 4 tabs (Overview, Plan, Budget, Team)
- OverviewTab, PlanTab (expandable phase cards, status cycling), BudgetTab, TeamTab
- Phase create/edit form screen
- Data access layers for phases, collaborators, notes
- ~100 i18n keys added (EN/ES/FR)

**Infrastructure:**
- Migrations generated and deployed to production
- 11 permissions seeded on both dev and prod DBs
- Role assignments: CUSTOMER (all 11), SERVICE_PROVIDER (4 read-only)

---

## Remaining Work

### Sprint 7: Notifications & Polish (NOT STARTED)

#### 7.1 New Notification Types
Add to shared-dto NotificationTypeENUM + category mappings:
- `PROJECT_PLAN_GENERATED` — plan is ready for review
- `PROJECT_COLLABORATOR_INVITED` — you've been invited to collaborate
- `PROJECT_COLLABORATOR_JOINED` — a collaborator accepted your invite
- `PROJECT_NOTE_ADDED` — someone added a note to your project
- `PROJECT_PHASE_COMPLETED` — a phase was marked complete
- `PROJECT_QUOTE_RECEIVED` — a quote was received for a phase

#### 7.2 Event Controllers
New event controller(s) for project planning events, following existing pattern in `projulous-svc/src/notification/eventControllers/`.

#### 7.3 E2E Testing
- Playwright tests for web project planning flow
- Maestro tests for mobile project planning flow

#### 7.4 Polish Items (TBD)
- [ ] Drag-to-reorder phases on web (currently ordered by phaseOrder field)
- [ ] Phase timeline/Gantt visualization
- [ ] Home screen PJ -> complex project detection -> auto-navigate to project detail
- [ ] Quote management per phase (link existing QuoteRequest to phases)
- [ ] Budget variance alerts/warnings

### Phase 6: Collaborator Auth & Access (NOT STARTED)

#### 6.1 Invite Flow
1. Owner enters collaborator email + name
2. System creates ProjectCollaborator record with inviteToken
3. Email notification sent with invite link
4. Collaborator clicks link -> if they have an account, links to it; if not, prompts signup
5. After acceptance, collaborator can view project and add notes

#### 6.2 Access Control
- New middleware/guard that checks ProjectCollaborator table
- Collaborators get read access to project + phases + budget
- Collaborators can update phase status and add notes
- Collaborators cannot delete phases, modify budget estimates, or remove other collaborators

---

## Original Plan Reference

### Context

Users currently interact with PJ (our AI agent) primarily to find service providers for simple tasks. But home projects are often complex multi-phase endeavors — a bathroom remodel involves demolition, plumbing, electrical, tile, paint, fixtures, and more. Users need a way to plan, track, budget, and manage these projects holistically with AI assistance.

This feature transforms PJ from a service-finder into a full project planning partner. PJ will interview users about their project, generate comprehensive project plans with phases, classify DIY vs professional work, estimate budgets, and provide ongoing guidance. The project detail page becomes a central hub for tracking phases, managing quotes, monitoring budgets, and collaborating with contractors/PMs.

### Key Decisions:
- **Separate flow** on My Projects tab, but PJ on home screen detects complex projects and hands off
- **Full V1** — scoping, tracking, quote management, budget vs actuals, collaborator invites
- **All interior/exterior home** project types
- **Collaborators**: view + update status + add notes/suggestions (not full edit)
- **Budget**: Both manual entry AND quote-linked
- **Plan editing**: Hybrid (direct edit + AI-mediated changes)

### Reference Mockup:
- **`mocks/project-planner-v1.html`** — Interactive HTML mockup showing the full UI

---

## Verification Plan

1. **Unit Tests**: Service tests for phase CRUD, collaborator invite flow, note CRUD (partially complete — collaborator 19 tests, note 10 tests)
2. **AI Integration Tests**: Test project scoping, plan generation, intent detection with mock LLM responses (NOT STARTED)
3. **E2E Web**: Playwright tests for project planning flow (NOT STARTED)
4. **E2E Mobile**: Maestro tests for mobile project planning flow (NOT STARTED)
5. **Manual Testing**:
   - Create a project via PJ on home screen
   - Verify PJ interviews user and generates plan
   - Verify phases appear in project detail
   - Test budget tracking (manual entry + quote linking)
   - Test collaborator invite flow
   - Test collaborator note/suggestion flow
   - Test plan editing (direct + via PJ)
   - Test all three languages (EN/ES/FR)

---

## Migration Reminder

Entity/schema changes require:
1. Build & push `projulous-shared-dto-node` to git
2. `npm install projulous-shared-dto-node` in projulous-svc
3. `npm run migration:generate -- src/migrations/DescriptiveName`
4. Review generated SQL
5. Commit migration file
6. On deploy, migrations auto-run via `migrationsRun: true`
