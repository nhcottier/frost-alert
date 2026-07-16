# Frost Alert Monetisation Plan

## Recommended Launch Model
Use a free trial followed by a one-time paid unlock.

Recommended structure:
- 7-day free trial.
- One-time lifetime unlock after trial.
- Suggested launch price: NZD $9.99 or USD $4.99 equivalent.
- Implement as a StoreKit non-consumable in-app purchase.

This fits Frost Alert better than freemium because the app is a focused utility. Users should be able to evaluate whether it helps them, then pay once for ongoing use without feeling managed into a subscription.

## Why Not Subscription First
A subscription may be harder to justify at launch because the app currently uses on-device scheduling and Apple Weather. It does not yet provide server-backed monitoring, premium forecast sources, historical analytics, sensor integrations, or professional crop-management features.

Subscriptions become more credible later if Frost Alert adds:
- Server-side forecast checks and remote push alerts.
- More reliable unattended monitoring.
- Multiple forecast providers.
- Crop-specific frost advice.
- Orchard/vineyard block grouping.
- Sensor integrations.
- Exportable risk reports.

## Trial Behaviour
On first launch, store a local trial start date.

During trial:
- All features are available.
- Show subtle trial status in settings or an unlock screen, not as a distracting banner on the dashboard.

After trial:
- Keep saved locations.
- Allow viewing limited saved data.
- Require purchase to refresh forecasts, add locations, schedule alerts, or use widgets.

## App Store Product
Create one non-consumable in-app purchase:

Product ID:
`com.nickcottier.frostalert.lifetime`

Display name:
`Frost Alert Lifetime`

Description:
`Unlock ongoing frost forecasts, alerts, widgets, and growing locations.`

## Customer Promise
Use careful wording:

Good:
`Frost Alert schedules alerts from the latest forecast refreshed by the app.`

Avoid:
`Guaranteed frost monitoring even when you never open the app.`

Reason:
iOS background refresh and local notifications are useful, but not guaranteed to fetch fresh forecasts indefinitely if the app is force-quit, rarely opened, or restricted by the system.

## Future Paid Tier
If server-side monitoring is added later, consider a separate subscription:

`Frost Alert Pro`
- Remote push alerts checked by a server.
- More frequent forecast checks.
- More locations.
- Advanced crop profiles.
- Professional frost-system reminders.

Do not launch with this until the backend exists.
