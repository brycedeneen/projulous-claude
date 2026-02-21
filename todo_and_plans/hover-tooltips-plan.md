# Hover Tooltips Plan for projulous-web

**Date**: 2026-02-20
**Status**: Plan Only (no code changes)
**Scope**: Add `title` attributes (native browser hover tooltips) to all icon-only buttons, links, and interactive elements that lack visual text labels.

---

## 1. Summary

After auditing all `.tsx` files in `projulous-web/app/`, this plan identifies **~60 interactive elements across ~30 files** that would benefit from a `title` attribute to provide hover tooltip text. These are elements where:

- The element is icon-only (no visible text label)
- The element currently has `aria-label` (screen reader only) but no `title` (no hover tooltip)
- OR the element has neither `aria-label` nor `title`

Elements are **skipped** when they:
- Already have a `title` attribute
- Have visible text alongside the icon that serves as a sufficient label
- Are purely decorative or part of a larger labeled container

---

## 2. Implementation Approach

### Recommendation: Use Native `title` Attributes

Use the native HTML `title` attribute rather than a custom Tooltip component. Rationale:

1. **Simplicity**: No new component needed; just add `title="..."` to existing elements
2. **Consistency**: The app already uses `title` in ~30+ places (sidebar nav, notification center, budget breakdown, feedback button)
3. **Zero JS overhead**: Native browser tooltips require no JavaScript
4. **Accessibility**: `title` provides both hover tooltips AND supplementary screen reader info

### Key Architectural Change: Shared Button Component

The single highest-impact change is modifying `app/shared/components/button.tsx` (line 160-172). The shared `Button` component accepts an `accessibilityName` prop that currently maps to `aria-label` only. Adding `title={accessibilityName}` to both the `<Link>` and `<Headless.Button>` renders will automatically provide tooltips to **all ~15+ icon-only Button usages** across the app without touching individual files.

**Change in `button.tsx`:**
- Line 164: Add `title={accessibilityName}` to the `<Link>` element
- Line 168: Add `title={accessibilityName}` to the `<Headless.Button>` element

**Consideration**: For Buttons with visible text children (e.g., `<Button>Edit</Button>`), the tooltip will show the same text as the button label, which is harmless but redundant. If this is undesirable, add an optional `hideTooltip` prop to suppress the `title` when visible text is present.

---

## 3. File-by-File Inventory

All paths relative to `projulous-web/app/`. Absolute base: `/Users/brycedeneen/dev/projulous/projulous-web/app/`

### Priority 1: Shared Component (Highest Impact)

| File | Line | Element | Icon | Current State | Suggested title |
|------|------|---------|------|---------------|-----------------|
| `shared/components/button.tsx` | 164 | `<Link>` | varies | `aria-label={accessibilityName}` only | Add `title={accessibilityName}` |
| `shared/components/button.tsx` | 168 | `<Headless.Button>` | varies | `aria-label={accessibilityName}` only | Add `title={accessibilityName}` |

**Impact**: This single change automatically adds tooltips to all icon-only `<Button>` usages including:
- `deviceCard.component.tsx` lines 73, 77, 80 (Camera scan, Pencil edit, Trash2 delete)
- `maintenanceScheduleSection.component.tsx` lines 183, 186, 189-197 (CheckCircle complete, Pencil edit, Trash delete)
- `PromptInput.tsx` lines 667-676, 681-687 (AI Model pill, Voice Input mic)

### Priority 2: Customer-Facing Pages

| File | Line | Element | Icon | Current State | Suggested title |
|------|------|---------|------|---------------|-----------------|
| `routes/customers/projects/projectDetail.route.tsx` | 308 | `<Link>` back nav | SVG chevron-left | No aria-label, no title | `title={t('tooltips.backToProjects')}` |
| `routes/customers/projects/projectDetail.route.tsx` | 528-535 | `<button>` remove SP | Trash2 | `aria-label` with dynamic SP name | Add matching `title` |
| `routes/customers/projects/components/CollaboratorList.component.tsx` | 65 | `<button>` remove collaborator | X | `aria-label` with dynamic name | Add matching `title` |
| `routes/customers/projects/components/BudgetBreakdown.component.tsx` | 226 | `<button>` expand/collapse phase | ChevronDown/Right | No aria-label, no title | `title={t('tooltips.expandCollapse')}` + add `aria-label` |
| `routes/customers/projects/components/BudgetBreakdown.component.tsx` | 489-497 | `<button>` cancel inline add | X | No aria-label, no title | `title={t('tooltips.cancel')}` + add `aria-label` |
| `routes/customers/projects/components/PhaseCard.component.tsx` | 50-57 | `<div>` drag handle | GripVertical | No aria-label, no title | `title={t('tooltips.dragToReorder')}` |
| `routes/customers/tickets/ticketDetail.route.tsx` | 110-116 | `<button>` back nav | ArrowLeft | `aria-label={t('myTickets.backToTickets')}` | Add matching `title` |

### Priority 3: Navigation & Footer

| File | Line | Element | Icon | Current State | Suggested title |
|------|------|---------|------|---------------|-----------------|
| `nav/sidebar.tsx` | 186 | `<button>` hamburger menu | Menu | `aria-label` (open/close sidebar) | Add matching `title` |
| `shared/components/footer.component.tsx` | 33-37 | `<a>` social media links (loop) | Dynamic social icons | `sr-only` text only | Add `title={t(item.name)}` |

### Priority 4: Help Center & Feedback

| File | Line | Element | Icon | Current State | Suggested title |
|------|------|---------|------|---------------|-----------------|
| `routes/helpCenter/components/VoteButton.tsx` | 16-29 | `<button>` vote up/down | ThumbsUp/ThumbsDown | `aria-label` with direction + count | Add matching `title` |
| `routes/helpCenter/components/CommentSection.tsx` | 106-113 | `<button>` delete comment | Trash2 | `aria-label={t('feedback.detail.deleteComment')}` | Add matching `title` |

### Priority 5: Admin Pages

#### Admin - Ideas

| File | Line | Element | Icon | Current State | Suggested title |
|------|------|---------|------|---------------|-----------------|
| `routes/admin/ideas/ideasAdmin.route.tsx` | 276-281 | `<button>` view idea | Eye | `aria-label="View"` | Add `title="View"` |
| `routes/admin/ideas/ideasAdmin.route.tsx` | 283-288 | `<button>` edit status | Edit | `aria-label="Edit status"` | Add `title="Edit status"` |
| `routes/admin/ideas/ideasAdmin.route.tsx` | 290-295 | `<button>` merge | GitMerge | `aria-label="Merge"` | Add `title="Merge"` |
| `routes/admin/ideas/ideasAdmin.route.tsx` | 297-302 | `<button>` delete | Trash2 | `aria-label="Delete"` | Add `title="Delete"` |

#### Admin - Help Center

| File | Line | Element | Icon | Current State | Suggested title |
|------|------|---------|------|---------------|-----------------|
| `routes/admin/helpCenter/helpCenterAdmin.route.tsx` | 483-489 | `<Link>` edit article | Pencil | `aria-label` with article name | Add matching `title` |
| `routes/admin/helpCenter/helpCenterAdmin.route.tsx` | 490-497 | `<button>` delete article | Trash2 | `aria-label` with article name | Add matching `title` |
| `routes/admin/helpCenter/helpCenterAdmin.route.tsx` | 603-610 | `<button>` edit category | Pencil | `aria-label` with category name | Add matching `title` |
| `routes/admin/helpCenter/helpCenterAdmin.route.tsx` | 611-617 | `<button>` delete category | Trash2 | `aria-label` with category name | Add matching `title` |
| `routes/admin/helpCenter/helpCenterAdmin.route.tsx` | 714-721 | `<button>` edit FAQ | Pencil | `aria-label="Edit FAQ"` | Add `title="Edit FAQ"` |
| `routes/admin/helpCenter/helpCenterAdmin.route.tsx` | 722-728 | `<button>` delete FAQ | Trash2 | `aria-label="Delete FAQ"` | Add `title="Delete FAQ"` |
| `routes/admin/helpCenter/helpCenterAdmin.route.tsx` | 752-759 | `<button>` close modal | X | `aria-label="Close modal"` | Add `title={t('tooltips.closeModal')}` |
| `routes/admin/helpCenter/helpCenterAdmin.route.tsx` | 869-876 | `<button>` close modal | X | `aria-label="Close modal"` | Add `title={t('tooltips.closeModal')}` |

#### Admin - Help Center Categories

| File | Line | Element | Icon | Current State | Suggested title |
|------|------|---------|------|---------------|-----------------|
| `routes/admin/helpCenter/helpCenterCategories.route.tsx` | 227-234 | `<button>` edit category | Pencil | `aria-label` with name | Add matching `title` |
| `routes/admin/helpCenter/helpCenterCategories.route.tsx` | 235-241 | `<button>` delete category | Trash2 | `aria-label` with name | Add matching `title` |
| `routes/admin/helpCenter/helpCenterCategories.route.tsx` | 267-274 | `<button>` close modal | X | `aria-label="Close modal"` | Add `title={t('tooltips.closeModal')}` |

#### Admin - Help Center FAQs

| File | Line | Element | Icon | Current State | Suggested title |
|------|------|---------|------|---------------|-----------------|
| `routes/admin/helpCenter/helpCenterFaqs.route.tsx` | 200-205 | `<button>` edit FAQ | Pencil | `aria-label` with FAQ text | Add matching `title` |
| `routes/admin/helpCenter/helpCenterFaqs.route.tsx` | 207-212 | `<button>` delete FAQ | Trash2 | `aria-label` with FAQ text | Add matching `title` |
| `routes/admin/helpCenter/helpCenterFaqs.route.tsx` | 233 | `<button>` close modal | X | `aria-label="Close modal"` | Add `title={t('tooltips.closeModal')}` |

#### Admin - Vendor Pages

| File | Line | Element | Icon | Current State | Suggested title |
|------|------|---------|------|---------------|-----------------|
| `routes/admin/vendorPages/vendorPageAdmin.route.tsx` | 148-153 | `<Link>` edit page | Pencil | `aria-label` with name | Add matching `title` |
| `routes/admin/vendorPages/vendorPageAdmin.route.tsx` | 155-162 | `<button>` delete page | Trash2 | `aria-label` with name | Add matching `title` |
| `routes/admin/vendorPages/vendorPageAdmin.route.tsx` | 183-190 | `<button>` close modal | X | `aria-label="Close modal"` | Add `title={t('tooltips.closeModal')}` |
| `routes/admin/vendorPages/vendorPageEditor.route.tsx` | 614-621 | `<button>` edit service type | Pencil | `aria-label` with name | Add matching `title` |
| `routes/admin/vendorPages/vendorPageEditor.route.tsx` | 622-629 | `<button>` delete service type | Trash2 | `aria-label` with name | Add matching `title` |
| `routes/admin/vendorPages/vendorPageEditor.route.tsx` | 691-698 | `<button>` edit FAQ | Pencil | `aria-label="Edit FAQ"` | Add `title="Edit FAQ"` |
| `routes/admin/vendorPages/vendorPageEditor.route.tsx` | 699-704 | `<button>` delete FAQ | Trash2 | `aria-label="Delete FAQ"` | Add `title="Delete FAQ"` |
| `routes/admin/vendorPages/vendorPageEditor.route.tsx` | 787-793 | `<button>` edit showcase | Pencil | `aria-label="Edit showcase project"` | Add matching `title` |
| `routes/admin/vendorPages/vendorPageEditor.route.tsx` | 795-800 | `<button>` delete showcase | Trash2 | `aria-label="Delete showcase project"` | Add matching `title` |
| `routes/admin/vendorPages/vendorPageEditor.route.tsx` | 824-831 | `<button>` close modal | X | `aria-label="Close modal"` | Add `title={t('tooltips.closeModal')}` |
| `routes/admin/vendorPages/vendorPageEditor.route.tsx` | 914-921 | `<button>` close modal | X | `aria-label="Close modal"` | Add `title={t('tooltips.closeModal')}` |
| `routes/admin/vendorPages/vendorPageEditor.route.tsx` | 996-1003 | `<button>` close modal | X | `aria-label="Close modal"` | Add `title={t('tooltips.closeModal')}` |

#### Admin - SP Review

| File | Line | Element | Icon | Current State | Suggested title |
|------|------|---------|------|---------------|-----------------|
| `routes/admin/serviceProviderReview/serviceProviderReviewerDashboard.route.tsx` | 240-247 | `<button>` view provider | Eye | `aria-label` with name | Add matching `title` |
| `routes/admin/serviceProviderReview/serviceProviderManagement.route.tsx` | 397-404 | `<button>` view provider | Eye | `aria-label` with name | Add matching `title` |
| `routes/admin/serviceProviderReview/serviceProviderManagement.route.tsx` | 545-552 | `<button>` edit offering | Eye | `aria-label` with name | Add matching `title` |
| `routes/admin/serviceProviderReview/serviceProviderManagement.route.tsx` | 716-723 | `<button>` view provider | Eye | `aria-label` with name | Add matching `title` |
| `routes/admin/serviceProviderReview/components/ProviderFormModal.tsx` | 124-131 | `<button>` close modal | X | `aria-label="Close modal"` | Add `title={t('tooltips.closeModal')}` |
| `routes/admin/serviceProviderReview/components/OfferingFormModal.tsx` | 105-112 | `<button>` close modal | X | `aria-label="Close modal"` | Add `title={t('tooltips.closeModal')}` |

#### Admin - Roles

| File | Line | Element | Icon | Current State | Suggested title |
|------|------|---------|------|---------------|-----------------|
| `routes/admin/roleManagement/roleManagement.route.tsx` | 174-179 | `<Link>` view role | Eye | `aria-label` with name | Add matching `title` |
| `routes/admin/roleManagement/roleManagement.route.tsx` | 182-189 | `<button>` delete role | Trash2 | `aria-label` with name | Add matching `title` |

#### Admin - Users

| File | Line | Element | Icon | Current State | Suggested title |
|------|------|---------|------|---------------|-----------------|
| `routes/admin/userManagement/userManagementDashboard.route.tsx` | 437-443 | `<Link>` view user | Eye | `aria-label` with name | Add matching `title` |
| `routes/admin/userManagement/userManagementDashboard.route.tsx` | 445-451 | `<DropdownButton>` more actions | MoreHorizontal | `aria-label` with name | Add matching `title` |
| `routes/admin/userManagement/userDetail.route.tsx` | 294-301 | `<button>` back nav | ArrowLeft | `aria-label="Back to user list"` | Add `title="Back to user list"` |
| `routes/admin/userManagement/userDetail.route.tsx` | 429-437 | `<button>` remove role | X | `aria-label` with role name | Add matching `title` |

#### Admin - Audit & AI Logs

| File | Line | Element | Icon | Current State | Suggested title |
|------|------|---------|------|---------------|-----------------|
| `routes/admin/audit/auditLogAdmin.route.tsx` | 387 | `<button>` expand/collapse | ChevronUp/Down | `aria-label` (Expand/Collapse row) | Add matching `title` |
| `routes/admin/aiLogs/aiLogsAdmin.route.tsx` | 217 | `<button>` expand/collapse | ChevronUp/Down | `aria-label` (Expand/Collapse row) | Add matching `title` |

#### Admin - Support Tickets

| File | Line | Element | Icon | Current State | Suggested title |
|------|------|---------|------|---------------|-----------------|
| `routes/admin/supportTickets/supportTicketAdmin.route.tsx` | 251-258 | `<button>` view ticket | Eye | `aria-label` with subject | Add matching `title` |
| `routes/admin/supportTickets/supportTicketDetail.route.tsx` | 125-131 | `<button>` back nav | ArrowLeft | `aria-label={t('supportTickets.detail.backToList')}` | Add matching `title` |

### Priority 6: Service Provider Pages

| File | Line | Element | Icon | Current State | Suggested title |
|------|------|---------|------|---------------|-----------------|
| `routes/serviceProviders/team/teamManagement.route.tsx` | 381-387 | `<Link>` view member | Eye | `aria-label` with name | Add matching `title` |
| `routes/serviceProviders/team/teamManagement.route.tsx` | 514-521 | `<button>` reactivate member | UserPlus | `aria-label` with name | Add matching `title` |
| `routes/serviceProviders/team/teamMemberDetail.route.tsx` | 191-198 | `<button>` back nav | ArrowLeft | `aria-label={t('teamManagement.detail.backToTeam')}` | Add matching `title` |
| `routes/serviceProviders/tickets/spTicketDetail.route.tsx` | 73-79 | `<button>` back nav | ArrowLeft | `aria-label={t('spTickets.backToTickets')}` | Add matching `title` |
| `routes/serviceProviders/tickets/spTicketList.component.tsx` | 232-239 | `<button>` view ticket | Eye | `aria-label` with subject | Add matching `title` |
| `routes/serviceProviders/billing/billing.route.tsx` | 146-148 | `<button>` dismiss error | X | `aria-label="Dismiss"` | Add `title="Dismiss"` |

---

## 4. Translation Keys Needed

Most elements already have translated `aria-label` values via existing i18n keys. The `title` should reuse the same key as `aria-label` wherever possible (e.g., `title={t('myTickets.backToTickets')}`).

**New translation keys needed** (add to `en.json`, `es.json`, `fr.json`):

```json
{
  "tooltips": {
    "backToProjects": "Back to projects",
    "expandCollapse": "Expand/collapse",
    "cancel": "Cancel",
    "closeModal": "Close",
    "dragToReorder": "Drag to reorder",
    "view": "View",
    "edit": "Edit",
    "editStatus": "Edit status",
    "delete": "Delete",
    "merge": "Merge",
    "dismiss": "Dismiss"
  }
}
```

**Spanish (`es.json`):**
```json
{
  "tooltips": {
    "backToProjects": "Volver a proyectos",
    "expandCollapse": "Expandir/contraer",
    "cancel": "Cancelar",
    "closeModal": "Cerrar",
    "dragToReorder": "Arrastrar para reordenar",
    "view": "Ver",
    "edit": "Editar",
    "editStatus": "Editar estado",
    "delete": "Eliminar",
    "merge": "Fusionar",
    "dismiss": "Descartar"
  }
}
```

**French (`fr.json`):**
```json
{
  "tooltips": {
    "backToProjects": "Retour aux projets",
    "expandCollapse": "Agrandir/reduire",
    "cancel": "Annuler",
    "closeModal": "Fermer",
    "dragToReorder": "Glisser pour reorganiser",
    "view": "Voir",
    "edit": "Modifier",
    "editStatus": "Modifier le statut",
    "delete": "Supprimer",
    "merge": "Fusionner",
    "dismiss": "Fermer"
  }
}
```

**Note**: Many elements already use translated `aria-label` values via existing keys (e.g., `t('myTickets.backToTickets')`, `t('nav.closeSidebar')`, `t('maintenance.actions.edit')`). For these, simply duplicate the value: `title={t('existing.key')}`. No new key is needed for these cases.

---

## 5. Elements Skipped (Already Covered or Not Needed)

### Already Have `title` Attributes
- `nav/sidebar.tsx` — All 28 nav item buttons (lines 199-462)
- `shared/components/feedback/FeedbackButton.tsx` — Both `title` and `aria-label`
- `routes/notifications/notificationCenter.route.tsx` — Icon buttons have both `title` and `aria-label`
- `routes/customers/projects/components/BudgetBreakdown.component.tsx` — Calculator, Check, FileText, Pencil, Trash2 buttons
- `routes/admin/userManagement/userManagementDashboard.route.tsx` — Auth method icons
- `routes/customers/projects/components/CollaboratorList.component.tsx` — Email truncation tooltip

### Have Visible Text Alongside Icons (No Tooltip Needed)
- `routes/customers/projects/projectDetail.route.tsx` — Edit/Delete buttons with text
- `routes/customers/appliances/applianceTile.component.tsx` — Edit/Delete with text
- `routes/customers/places/placeTile.component.tsx` — Edit/Delete with text
- `routes/customers/projects/projectTile.component.tsx` — Edit/Delete with text
- `routes/helpCenter/helpCenterArticle.route.tsx` — Yes/No helpful buttons with text
- `routes/home/components/PromptInput.tsx` — "Go" button with text
- All `searchFilterBar.component.tsx` buttons — Clear filters with text
- `routes/customers/projects/components/PhaseList.component.tsx` — Add phase button with text

---

## 6. Implementation Pattern

For elements with existing `aria-label`, the pattern is simple — add a matching `title`:

**Before:**
```tsx
<button aria-label={`Edit ${item.name}`}>
  <Pencil className="h-4 w-4" />
</button>
```

**After:**
```tsx
<button aria-label={`Edit ${item.name}`} title={`Edit ${item.name}`}>
  <Pencil className="h-4 w-4" />
</button>
```

For elements with **neither** `aria-label` nor `title`, add both:

**Before:**
```tsx
<button onClick={toggle} className="...">
  <ChevronDown className="h-4 w-4" />
</button>
```

**After:**
```tsx
<button onClick={toggle} className="..." aria-label={t('tooltips.expandCollapse')} title={t('tooltips.expandCollapse')}>
  <ChevronDown className="h-4 w-4" />
</button>
```

For the **shared Button component** (`button.tsx`):

**Before (line 164):**
```tsx
<Link {...props} className={classes} ref={ref} aria-label={accessibilityName}>
```

**After:**
```tsx
<Link {...props} className={classes} ref={ref} aria-label={accessibilityName} title={accessibilityName}>
```

**Before (line 168):**
```tsx
<Headless.Button {...props} className={clsx(classes, 'cursor-pointer')} ref={ref} aria-label={accessibilityName}>
```

**After:**
```tsx
<Headless.Button {...props} className={clsx(classes, 'cursor-pointer')} ref={ref} aria-label={accessibilityName} title={accessibilityName}>
```

---

## 7. Testing Checklist

- [ ] Hover over every modified element and verify tooltip appears
- [ ] Verify tooltip text matches the element's purpose
- [ ] Test in both light and dark modes (tooltips are browser-native, should work in both)
- [ ] Test with keyboard focus (native `title` may not show on focus; this is acceptable)
- [ ] Verify no double tooltips (ensure elements don't have both custom and native tooltips)
- [ ] Test on mobile (native tooltips don't show on touch; this is expected and acceptable)
- [ ] Run `npm run typecheck` to verify no TypeScript errors
- [ ] Test that shared Button component change doesn't cause regressions on Buttons with visible text
- [ ] Verify translations render correctly in ES and FR

---

## 8. Estimated Effort

| Priority | Files | Elements | Effort |
|----------|-------|----------|--------|
| P1: Shared Button | 1 | 2 (affects ~15+ usages) | 5 min |
| P2: Customer Pages | 5 | 7 | 15 min |
| P3: Navigation | 2 | 2+ (loop) | 5 min |
| P4: Help Center | 2 | 2 | 5 min |
| P5: Admin Pages | 15 | ~35 | 30 min |
| P6: SP Pages | 4 | 6 | 10 min |
| Translation Keys | 3 | ~11 new keys | 10 min |
| **Total** | **~30** | **~60** | **~80 min** |

---

## 9. Notes

1. **Dynamic `aria-label` values**: Many admin page elements use dynamic aria-labels like `` aria-label={`Edit ${item.name}`} ``. The `title` should use the exact same expression.

2. **Hardcoded English strings**: Some `aria-label` values are hardcoded in English (e.g., `"View"`, `"Edit status"`, `"Merge"`, `"Close modal"`) rather than using `t()`. When adding `title`, consider also converting these to i18n keys for consistency.

3. **The `DropdownButton` component**: The `userManagementDashboard.route.tsx` uses `<DropdownButton>` from Headless UI. Verify that `title` works correctly on this component (it should, as it renders as a native button).

4. **Drag handle**: The PhaseCard drag handle (line 50-57) is a `<div>`, not a `<button>`. Adding `title="Drag to reorder"` still works on div elements.

5. **Close modal pattern**: There are ~12 close-modal X buttons across admin pages. These all follow the same pattern and should all use `title={t('tooltips.closeModal')}`.
