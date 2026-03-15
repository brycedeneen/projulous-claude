# Styled Email Templates - Implementation Plan

## Status: Phase 1 Complete

## Architecture

- **Source templates**: `projulous-svc/src/mail/mjml/*.mjml` (MJML markup)
- **Compiled templates**: `projulous-svc/src/mail/templates/*.hbs` (generated HTML with Handlebars placeholders)
- **Compile script**: `npm run build:emails` (MJML → HBS, run before deploy)
- **Template service**: `EmailTemplateService` (global, renders HBS with context)
- **Preview**: `GET /v1/email-preview` (dev-only, browse all templates in browser)
- **Sending**: Existing `EmailService` (AWS SES) with new `htmlBody` parameter

## Design System

| Element | Value |
|---------|-------|
| Background | `#f4f4f5` (zinc-100) |
| Card | `#ffffff` |
| Primary text | `#18181b` (zinc-900) |
| Muted text | `#71717a` (zinc-500) |
| CTA button | `#4F46E5` (indigo-600) |
| Dividers | `#e4e4e7` (zinc-200) |
| Font stack | -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif |
| Max width | 600px (MJML default) |
| Button padding | 14px 32px, 8px border-radius |

## Email Templates - All Types

### Phase 1: Auth & Core (DONE)

| Template | File | Status |
|----------|------|--------|
| Email Verification | `email-verification.mjml` | Done |
| Password Reset | `password-reset.mjml` | Done |
| Welcome SP | `welcome-sp.mjml` | Done |
| Team Invite | `team-invite.mjml` | Done |
| Project Collaborator Invite | `project-collaborator-invite.mjml` | Done |
| Place Co-Owner Invite | `place-co-owner-invite.mjml` | Done |
| SP Claim Verification | `sp-claim-verification.mjml` | Done |
| Quote Request | `quote-request.mjml` | Done |

All 8 event handlers updated to use HTML templates with plain text fallback.

### Phase 2: SP Certification Email (Deferred)

The SP certification email (`SP_CERTIFICATION_EMAIL_SENT`) has dynamic content from external sources (certification bodies). It currently sends the raw body provided by the certification service. Two options:

1. **Wrap in branded shell**: Keep the dynamic body but wrap it in a branded header/footer template
2. **Leave as-is**: Since these are quasi-automated external communications, plain text may be appropriate

**Recommendation**: Option 1 — create a `generic-branded.mjml` template with header, `{{{body}}}` (triple-stache for raw HTML), and footer. Low effort, consistent branding.

### Phase 3: Future Email Types (Not Yet Implemented)

These event types exist in the codebase but don't have email handlers yet:

| Event Type | Description | Template Needed |
|------------|-------------|-----------------|
| `FEEDBACK_WEEKLY_DIGEST` | Weekly feedback summary | `feedback-digest.mjml` - Multi-item list layout |
| `BILLING_CHECKOUT_COMPLETED` | Payment confirmed | `billing-confirmation.mjml` - Receipt/invoice style |
| `BILLING_SUBSCRIPTION_UPDATED` | Plan change | `billing-subscription.mjml` - Plan comparison |
| `BILLING_INVOICE_PAID` | Invoice paid | `billing-receipt.mjml` - Receipt with line items |
| `BILLING_PAYMENT_FAILED` | Payment failure | `billing-payment-failed.mjml` - Warning/action style |

When these are implemented, create the MJML template first, compile, then wire up the event handler.

## Workflow for Adding New Email Templates

1. Create `src/mail/mjml/new-template.mjml` using existing templates as reference
2. Use `<mj-include path="./partials/header.mjml" />` and footer partial for branding
3. Run `npm run build:emails` to compile
4. Add sample data to `emailPreview.controller.ts` → `getSampleData()`
5. Preview at `http://localhost:8123/v1/email-preview/new-template`
6. Wire up the event handler with `this.emailTemplateService.render('new-template', { ... })`
7. Pass HTML as the last argument to `this.emailService.sendEmail()`

## Preview System

- **Index page**: `GET http://localhost:8123/v1/email-preview` — lists all templates as clickable links
- **Template preview**: `GET http://localhost:8123/v1/email-preview/:name` — renders with sample data
- **JSON mode**: `GET http://localhost:8123/v1/email-preview/:name?json=1` — returns raw HTML + context as JSON

No auth required (dev-only endpoint). Works when backend is running locally with `npm run start:dev`.

## Multi-Language Support (Future)

The templates use Handlebars context variables for all user-facing text. To add i18n:

1. Create a translation map per template (e.g., `emailTranslations.ts`)
2. In event handlers, look up user's `preferredLanguage`
3. Pass translated strings as context variables
4. No need for separate template files per language

This matches the existing i18n approach used in mobile/web.
