# Web Push Notifications — Future Implementation Plan

**Status:** Deferred (implement after SSE is live)
**Priority:** Low — SSE covers in-app real-time, mobile push covers native apps. Web Push fills the gap of "user has browser closed."

---

## What It Does

Sends OS-level browser notifications (like mobile push) even when the user doesn't have the Projulous tab open. Uses the W3C Push API standard — free, no additional AWS infrastructure.

---

## Prerequisites

- SSE implementation must be complete first (provides the real-time backbone)
- HTTPS in production (required by Push API — already have this)

---

## Infrastructure Required

- **VAPID keypair**: Generate once with `npx web-push generate-vapid-keys`, store as env vars (`VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY`, `VAPID_SUBJECT=mailto:support@projulous.com`)
- **No AWS changes**: Push messages are sent directly to browser vendor endpoints (Google FCM for Chrome, Mozilla for Firefox, Apple for Safari) over HTTPS from the backend
- **No message queue**: Same fire-and-forget pattern as Expo push notifications

---

## Backend Changes (projulous-svc)

### 1. New dependency: `web-push`
```bash
npm install web-push
```

### 2. New entity: `WebPushSubscription` (projulous-shared-dto-node)
```typescript
@Entity('WebPushSubscriptions')
export class WebPushSubscription {
  @PrimaryGeneratedColumn('uuid')
  webPushSubscriptionId: string;

  @Column('jsonb')
  subscription: PushSubscription; // { endpoint, keys: { p256dh, auth } }

  @Column()
  userAgent: string; // browser identifier for management

  @ManyToOne(() => User)
  user: Relation<User>;

  @Column(() => StandardFields)
  standardFields: StandardFields;
}
```

### 3. New service: `WebPushService`
- `subscribe(user, subscription)` — save browser push subscription to DB
- `unsubscribe(user, subscriptionId)` — remove subscription
- `sendWebPush(userId, notification)` — send push via `web-push` library
  - Load all user's WebPushSubscription records
  - Check user preferences (pushEnabled)
  - Send to each subscription endpoint
  - Handle 410 Gone (subscription expired) — auto-delete from DB
  - Fire-and-forget, errors logged not thrown

### 4. Hook into `notification.service.ts`
In `createNotification()`, alongside mobile push:
```typescript
this.webPushService.sendWebPush(userId, newRecord).catch(() => {});
```

### 5. REST endpoints for subscription management
```
POST   /v1/notifications/web-push-subscription    — Register subscription
DELETE /v1/notifications/web-push-subscription/:id — Unregister
```

---

## Frontend Changes (projulous-web)

### 1. Service Worker: `public/sw.js`
```javascript
self.addEventListener('push', (event) => {
  const data = event.data?.json() ?? {};
  // Don't show if tab is focused (SSE handles in-app)
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((tabs) => {
      const hasFocusedTab = tabs.some((tab) => tab.focused);
      if (!hasFocusedTab) {
        return self.registration.showNotification(data.title, {
          body: data.message,
          icon: '/icon-192.png',
          data: { link: data.link },
        });
      }
    })
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const link = event.notification.data?.link;
  if (link) {
    event.waitUntil(clients.openWindow(link));
  }
});
```

### 2. Service Worker registration + permission prompt
- Register SW on app load
- Show a custom in-app prompt (not the browser default) asking user to enable notifications
- On acceptance, call `Notification.requestPermission()`, then `registration.pushManager.subscribe()` with the VAPID public key
- Send the subscription object to the backend via POST

### 3. Settings page update
- Add a "Browser Notifications" toggle alongside the existing push/email toggles
- This controls whether the SW shows notifications (separate from mobile push)

---

## Duplicate Notification Prevention

The Service Worker checks `clients.matchAll()` to see if any Projulous tab is focused. If yes, it skips the OS notification (SSE already showed it in-app). This prevents the user from seeing the same notification twice.

---

## Browser Support

| Browser | Support |
|---------|---------|
| Chrome | Full (via FCM) |
| Firefox | Full (via Mozilla push) |
| Safari | 16.4+ (macOS Ventura+, iOS 16.4+) |
| Edge | Full (via FCM) |

---

## Migration Required

- New `WebPushSubscriptions` table (entity registration in app.module.ts, feature module, data-source.ts)
- Generate migration after entity creation

---

## Estimated Effort

- Backend: ~4 hours (entity, service, endpoints, hook into createNotification)
- Frontend: ~4 hours (service worker, registration, permission prompt, settings toggle)
- Testing: ~2 hours (cross-browser, subscription lifecycle, duplicate prevention)

---

## Key Risks

- **Low opt-in rates** (5-15% typical for web push permission prompts)
- **Safari quirks** — newer support, may need testing
- **Service worker caching** — must handle SW updates carefully to avoid stale behavior
