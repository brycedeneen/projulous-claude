# SP Showcase Self-Publishing — Implementation Plan

## Context

Service providers on Pro/Pinnacle plans need to self-publish portfolio showcase posts about their completed work. These posts appear on the customer homepage ("Recent Projects Near Me") and the `/projects` browse page. A `ShowcaseProject` entity, admin-only CRUD, and customer-facing display pages already exist — this feature extends them for SP self-service with photos, AI writing feedback, and draft/publish workflow.

**Key decisions:**
- Immediately live on publish (no admin approval)
- S3 photo uploads (like AppliancePhoto pattern)
- Web SP portal only for creation; customers see on web + mobile
- Homepage GallerySection wired to real API data (replacing hardcoded placeholders)

---

## Phase 1: Shared DTO (projulous-shared-dto-node)

### 1.1 New enum: `ShowcaseProjectStatusENUM`
**File:** `shared/enums/showcaseProjectStatus.enum.ts` (new)
```typescript
export enum ShowcaseProjectStatusENUM {
  DRAFT = 'DRAFT',
  PUBLISHED = 'PUBLISHED',
}
```
Export from `shared/enums/index.ts`. Do NOT call `registerEnumType()` here (browser safety).

### 1.2 New entity: `ShowcaseProjectPhoto`
**File:** `showcase/showcaseProjectPhoto.entity.ts` (new)

Follow `customer/appliancePhoto.entity.ts` pattern:
- `showcaseProjectPhotoId` (uuid PK)
- `s3Key` (varchar 512, not null)
- `originalFilename` (varchar 256, nullable)
- `mimeType` (varchar 64, nullable)
- `fileSizeBytes` (int, nullable)
- `isPrimary` (boolean, default false)
- `displayOrder` (int, default 0)
- ManyToOne → `ShowcaseProject` (not null)
- ManyToOne → `ServiceProvider` (not null, for ownership checks)
- `standardFields`

### 1.3 Update `ShowcaseProject` entity
**File:** `showcase/showcaseProject.entity.ts`

Add columns:
- `status` — `enum ShowcaseProjectStatusENUM`, default `DRAFT`, not null
- `offeringType` — `enum OfferingTypeENUM`, nullable (use existing PG enum type)
- `postalCode` — `varchar(16)`, nullable (for geo-filtering)

Add OneToMany relation to `ShowcaseProjectPhoto`.

Register `ShowcaseProjectStatusENUM` with `registerEnumType()` in this entity file.

Add new SP-specific DTOs:
- `CreateShowcaseProjectSpDTO` — title, offeringType, summary?, storyParagraphs?, tags?, duration?, costRange?, completedDate?, status?
- `UpdateShowcaseProjectSpDTO` — all optional versions of above

### 1.4 Update barrel exports
**File:** `showcase/index.ts` — export `ShowcaseProjectPhoto`, new DTOs

---

## Phase 2: Backend (projulous-svc)

### 2.1 Entity registration (3 places)
- `src/app.module.ts` — add `ShowcaseProjectPhoto`
- `src/data-source.ts` — add `ShowcaseProjectPhoto`
- `src/showcase/showcase.module.ts` — add `ShowcaseProjectPhoto`, `ServiceProvider`, `ServiceProviderOffering` to entities

### 2.2 S3 key builder
**File:** `src/utils/storage/s3Storage.service.ts`

Add method:
```typescript
buildShowcasePhotoKey(spId: string, showcaseProjectId: string, fileId: string, filename: string): string
// Pattern: service-providers/{spId}/showcase/{showcaseProjectId}/{fileId}-{filename}
```

### 2.3 ShowcaseProjectPhoto service
**File:** `src/showcase/services/showcaseProjectPhoto.service.ts` (new)

Follow `appliancePhoto.service.ts` pattern exactly:
- `getPhotosForShowcaseProject(user, showcaseProjectId)` — returns photos with presigned URLs
- `uploadPhoto(user, spId, showcaseProjectId, file, isPrimary, displayOrder)` — S3 upload, enforce max 5, verify ownership + tier
- `deletePhoto(user, spId, photoId)` — S3 delete + soft delete, verify ownership
- `setPrimaryPhoto(user, spId, photoId)` — set one as primary, unset others

### 2.4 Update ShowcaseProject service
**File:** `src/showcase/services/showcaseProject.service.ts`

Add SP-specific methods (inject `ServiceProvider` and `ServiceProviderOffering` read repos):

- `getMyShowcaseProjects(user)` — returns all for user's SP (draft + published), ordered by createdDate DESC
- `getMyShowcaseProject(user, showcaseProjectId)` — single project, verify ownership, include photos with presigned URLs
- `createShowcaseProjectAsSp(user, dto)`:
  1. Get SP, check `membershipTier` is PRO or PINNACLE (throw ForbiddenException if not)
  2. Verify `offeringType` is in SP's configured offerings
  3. Auto-generate slug from title via slugify + 6-char random suffix
  4. Auto-populate provider* fields from SP profile
  5. Set postalCode from matching offering's `centerPointPostalCode`
  6. Default status to DRAFT
  7. Save + emit event
- `updateShowcaseProjectAsSp(user, id, dto)` — verify ownership, if offeringType changed validate against SP offerings, re-slug if title changed, emit event
- `deleteShowcaseProjectAsSp(user, id)` — verify ownership, soft-delete photos too, emit event

Update `getPublishedShowcaseProjects()`:
- Add `where: { status: ShowcaseProjectStatusENUM.PUBLISHED }` filter
- Accept optional `limit` param (default 20)
- Accept optional `offeringType` filter

### 2.5 SP REST controller
**File:** `src/showcase/controllers/showcaseProjectSp.controller.ts` (new)

Route prefix: `v1/service-providers/showcase-projects`

```
GET    /                -> getMyShowcaseProjects
GET    /:id             -> getMyShowcaseProject (with photos)
POST   /                -> createShowcaseProjectAsSp
PATCH  /:id             -> updateShowcaseProjectAsSp
DELETE /:id             -> deleteShowcaseProjectAsSp
```

Use `@Permissions(PermissionENUM.SHOWCASE_CREATE)` etc. (permissions already exist in the enum). SP ID extracted from user auth model (same pattern as `spSelfServiceProfile.controller.ts`).

### 2.6 Photo REST controller
**File:** `src/showcase/controllers/showcaseProjectPhoto.controller.ts` (new)

Route prefix: `v1/service-providers/showcase-projects/:showcaseProjectId/photos`

```
GET    /              -> getPhotos
POST   /              -> uploadPhoto (FileInterceptor, 10MB, jpeg/png/webp/heic)
DELETE /:photoId      -> deletePhoto
PATCH  /:photoId/primary -> setPrimaryPhoto
```

### 2.7 AI feedback service
**File:** `src/showcase/services/showcaseProjectAI.service.ts` (new)

Follow `feedbackAI.service.ts` pattern:
- `getWritingFeedback(title, summary, storyParagraphs, tags, offeringType, language)` → structured response
- Gemini Flash, temperature 0.3, `responseMimeType: 'application/json'`
- Zod schema for response: `{ overallScore: 1-10, strengths: string[], improvements: string[], suggestions: { section, feedback, suggestedText? }[] }`
- `withGeminiLogging` wrapper, new `AIOperationENUM.SHOWCASE_CONTENT_FEEDBACK`
- New prompt in `prompts.config.ts`: `showcaseContentFeedback`
- Prompt instructs PJ to evaluate clarity, professionalism, detail level, customer appeal

### 2.8 AI feedback controller
**File:** `src/showcase/controllers/showcaseProjectAI.controller.ts` (new)

```
POST /v1/service-providers/showcase-projects/:id/ai-feedback -> getAiFeedback
```

Requires PRO/PINNACLE tier. Loads current content from DB, passes to AI service.

### 2.9 Update GraphQL resolver
**File:** `src/showcase/resolvers/showcaseProject.resolver.ts`

- `getPublishedShowcaseProjects`: add `limit` arg, filter by `status: PUBLISHED`
- Add field resolver for `photos` → returns presigned URLs
- `getShowcaseProjectBySlug`: only return if PUBLISHED

### 2.10 Add event types
**File:** `src/shared/events/eventType.enum.ts`

```
SHOWCASE_PROJECT_PHOTO_UPLOAD = 'showcase_project_photo_upload'
SHOWCASE_PROJECT_PHOTO_DELETE = 'showcase_project_photo_delete'
```

### 2.11 Update showcase module
**File:** `src/showcase/showcase.module.ts`

Add new services, controllers, and entities to the module.

### 2.12 Add AIOperationENUM
**File:** `src/projulousAI/constants/aiInteractionConstants.ts`

Add `SHOWCASE_CONTENT_FEEDBACK = 'SHOWCASE_CONTENT_FEEDBACK'`

### 2.13 Add prompt
**File:** `src/projulousAI/prompts/prompts.config.ts`

Add `showcaseContentFeedback` prompt template + add to `PromptName` type.

---

## Phase 3: Frontend — SP Portal (projulous-web)

### 3.1 Data access
**File:** `app/dataAccess/showcase/showcaseSp.da.tsx` (new)

REST methods for SP CRUD + photo + AI feedback. Follow existing DA patterns.

### 3.2 Showcase list page
**File:** `app/routes/serviceProviders/showcase/spShowcaseList.route.tsx` (new)

- Header with "My Showcase Posts" title + "New Post" button
- 3 stat cards: Published (green), Drafts (amber), Total (blue) — clickable filters
- Search + status filter bar
- Table: Title (link to edit), Offering Type (badge), Status (badge), Date, Actions (edit, publish/unpublish toggle, delete)
- Empty state: encouraging copy + "Create Your First Post" CTA
- Tier gate: if FREE/STARTER, show upgrade prompt instead of list

### 3.3 Showcase editor page (create/edit)
**File:** `app/routes/serviceProviders/showcase/spShowcaseForm.route.tsx` (new)

Full-page two-column layout:
- **Sticky header**: Back button, status badge, "Save Draft" + "Publish" buttons
- **Left column** (flex-1): Title input, Summary input (120 chars), Story textarea (12 rows), "Ask PJ" button
- **Right column** (w-80, sticky): Offering Type select (SP's offerings only), Completed Date, Duration, Cost Range, Tags (chip input), Photo upload zone

Publish validation: title, summary, story (min 100 chars), at least 1 photo, offering type required.

### 3.4 Sub-components
**Files:** `app/routes/serviceProviders/showcase/components/` (new dir)

- `PhotoUploadZone.tsx` — Drag-and-drop area, click-to-browse fallback, 5 max, "3/5 photos" counter
- `PhotoThumbnailGrid.tsx` — 3-col grid of square thumbnails, click to set primary (amber star + "Cover" label), X to delete
- `TagInput.tsx` — Text input with pill/chip display, Enter/comma to add, X to remove, max 10
- `AiFeedbackPanel.tsx` — Slide-down panel below story textarea, shows score + strengths + improvements + per-section suggestions, dismiss button
- `DeleteShowcaseModal.tsx` — Confirm delete dialog (same as deleteOfferingModal pattern)

### 3.5 Route registration
**File:** `app/routes.ts`

Add inside the `/service-providers` prefix block (after line 99):
```typescript
route('/showcase', './routes/serviceProviders/showcase/spShowcaseList.route.tsx'),
route('/showcase/new', './routes/serviceProviders/showcase/spShowcaseForm.route.tsx'),
route('/showcase/:showcaseProjectId/edit', './routes/serviceProviders/showcase/spShowcaseForm.route.tsx'),
```

### 3.6 Sidebar navigation
**File:** `app/nav/sidebar.tsx`

Add "My Showcase" button after "My Offerings" (after line 396), using `Images` icon from lucide-react. Follows exact same button pattern as existing SP nav items.

### 3.7 i18n translations
**Files:** `app/translations/en/`, `es/`, `fr/` — add `spShowcase` namespace or keys under existing SP namespace.

---

## Phase 4: Homepage Wiring

### 4.1 Update GallerySection
**File:** `app/routes/home/components/GallerySection.tsx`

Replace hardcoded `GALLERY_ITEMS` with real API call:
- `useEffect` → `ShowcaseDA.getPublishedShowcaseProjects()` → take first 4
- Map to existing card layout (cover image from primary photo presigned URL, title, summary, link to `/projects/{slug}`)
- Graceful fallback: if no published posts exist, hide the section or show a placeholder message
- Loading skeleton while fetching

### 4.2 Update ShowcaseDA
**File:** `app/dataAccess/showcase/showcase.da.tsx`

Update GraphQL query to include `status`, `offeringType`, `photos` fields. Add `limit` arg.

### 4.3 Update project constants
**File:** `app/routes/projects/constants.ts`

Add `status`, `offeringType`, `postalCode`, `photos` to the ShowcaseProject interface.

---

## Phase 5: Permissions Seeding

Seed SHOWCASE_CREATE, SHOWCASE_READ, SHOWCASE_MODIFY, SHOWCASE_DELETE permissions and assign to SP roles (SERVICE_PROVIDER role for PRO/PINNACLE users). These exist in the TypeScript enum but may not be seeded in the DB.

---

## UX Design Details

### Editor Layout (Desktop)
```
┌──────────────────────────────────────────────────────────────────┐
│ ← Back to Showcase                         [Save Draft] [Publish] │
├──────────────────────────┬───────────────────────────────────────┤
│   LEFT COLUMN (prose)    │   RIGHT COLUMN (metadata + photos)   │
│   flex-1 min-w-0         │   w-80 xl:w-96 (sticky)              │
│                          │                                       │
│  Title *                 │  Offering Type *                      │
│  Summary                 │  Completed Date                       │
│  Story (textarea, tall)  │  Duration                             │
│  [Ask PJ] button         │  Cost Range                           │
│                          │  Tags (chip input)                    │
│                          │  Photos (drag-and-drop, up to 5)      │
│                          │  [thumb] [thumb] [thumb]              │
└──────────────────────────┴───────────────────────────────────────┘
```

### Photo Upload
- Dashed border drop zone, click-to-browse fallback
- Thumbnails in 3-col grid below, click thumbnail to set as primary (amber star + "Cover" label)
- X button to delete, counter shows "3/5 photos"
- At 5 photos, drop zone replaced with "Maximum photos reached" text

### AI Feedback ("Ask PJ")
- Slide-down panel below story textarea (not a modal — SP needs to see their text while reading feedback)
- Button: Sparkles icon + "Ask PJ for writing feedback"
- Loading state with spinner, story textarea dims briefly
- Response shows as prose suggestions — SP applies them manually
- Dismiss button to close panel
- Minimum 50 chars in story to activate

### Draft/Publish Flow
- Save Draft: saves immediately, stays in DRAFT, shows toast
- Publish: validates required fields, then publishes (immediately live)
- Already-published posts: button says "Update Post"
- Unpublish: from list page only (EyeOff icon), confirmation dialog

### Sidebar Placement
```
Dashboard
My Offerings
My Showcase        ← NEW (Images icon)
Team Management
Billing
SP Tickets
```

---

## Migration Reminder

After shared-dto changes:
1. Build & push `projulous-shared-dto-node` to git
2. `npm install projulous-shared-dto-node` in projulous-svc
3. `npm run migration:generate -- src/migrations/AddShowcaseProjectStatusAndPhotos`
4. Review migration SQL — should include:
   - `CREATE TYPE "public"."ShowcaseProjectStatusENUM" AS ENUM('DRAFT', 'PUBLISHED')`
   - `ALTER TABLE "ShowcaseProjects" ADD "status" ...DEFAULT 'DRAFT'`
   - `ALTER TABLE "ShowcaseProjects" ADD "offeringType" ...` (reuse existing PG enum)
   - `ALTER TABLE "ShowcaseProjects" ADD "postalCode" varchar(16)`
   - `CREATE TABLE "ShowcaseProjectPhotos" (...)`
5. Data migration: set existing showcase rows to `status = 'PUBLISHED'` if they should be visible

---

## Implementation Order

| Step | What | Depends On |
|------|------|-----------|
| 1 | Shared DTO: enum, entity, DTOs (Phase 1) | — |
| 2 | Build & push shared-dto, install in svc | Step 1 |
| 3 | Backend: entity registration, migration (2.1) | Step 2 |
| 4 | Backend: S3 key builder (2.2) | Step 3 |
| 5 | Backend: photo service + controller (2.3, 2.6) | Step 4 |
| 6 | Backend: SP showcase service + controller (2.4, 2.5) | Step 3 |
| 7 | Backend: AI feedback service + controller + prompt (2.7, 2.8, 2.12, 2.13) | Step 3 |
| 8 | Backend: GraphQL resolver updates (2.9) | Step 6 |
| 9 | Backend: events + module wiring (2.10, 2.11) | Steps 5-7 |
| 10 | Frontend: SP data access (3.1) | Step 6 |
| 11 | Frontend: showcase list page + sidebar nav (3.2, 3.6) | Step 10 |
| 12 | Frontend: showcase editor + components (3.3, 3.4) | Step 10 |
| 13 | Frontend: homepage wiring (4.1-4.3) | Step 8 |
| 14 | Permissions seeding (Phase 5) | Step 3 |

---

## Verification

1. **Backend**: Start with `npm run start:dev`, hit health check
2. **SP CRUD**: Login as SP user with PRO tier → create draft showcase, upload photos, set primary, save, publish
3. **Tier gate**: Login as FREE SP → verify cannot create showcase posts (ForbiddenException)
4. **AI feedback**: Click "Ask PJ" on a draft → verify structured feedback returns
5. **Homepage**: Load customer homepage → verify GallerySection shows real published posts
6. **Browse**: Navigate to `/projects` → verify published posts appear with correct photos
7. **Detail**: Click a showcase post → verify `/projects/:slug` renders correctly with story + gallery
8. **Draft isolation**: Verify drafts do NOT appear on homepage or `/projects` page

---

## Key Reference Files

| Purpose | File Path |
|---------|-----------|
| ShowcaseProject entity (to modify) | `projulous-shared-dto-node/showcase/showcaseProject.entity.ts` |
| AppliancePhoto entity (pattern for ShowcaseProjectPhoto) | `projulous-shared-dto-node/customer/appliancePhoto.entity.ts` |
| ShowcaseProject service (to extend) | `projulous-svc/src/showcase/services/showcaseProject.service.ts` |
| AppliancePhoto service (pattern for photo service) | `projulous-svc/src/customer/services/appliancePhoto.service.ts` |
| FeedbackAI service (pattern for AI feedback) | `projulous-svc/src/feedback/services/feedbackAI.service.ts` |
| Showcase module (to update) | `projulous-svc/src/showcase/showcase.module.ts` |
| SP self-service controller (pattern for SP endpoints) | `projulous-svc/src/serviceProvider/controllers/spSelfServiceProfile.controller.ts` |
| GallerySection (to wire up) | `projulous-web/app/routes/home/components/GallerySection.tsx` |
| SP sidebar nav (to add item) | `projulous-web/app/nav/sidebar.tsx` (lines 374-427) |
| Web routes (to add routes) | `projulous-web/app/routes.ts` (lines 88-103) |
| S3 storage service (to add key builder) | `projulous-svc/src/utils/storage/s3Storage.service.ts` |
| Prompts config (to add prompt) | `projulous-svc/src/projulousAI/prompts/prompts.config.ts` |
| AI operation enum (to add operation) | `projulous-svc/src/projulousAI/constants/aiInteractionConstants.ts` |
