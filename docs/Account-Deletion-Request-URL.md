# Account Deletion Request URL

Use this handoff when creating the public account deletion request URL required
for Google Play. This issue is not complete until the final hosted URL works,
is entered in Play Console, and is recorded below.

Issue: #440
Parent track: #464
Status: externally blocked until a web/backend owner hosts the page and a Play
Console owner enters the URL.

## Policy Source

- Google Play Console Help: [Understanding Google Play's app account deletion
  requirements](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en)
  (checked 2026-05-10).

## Required Outcome

- The URL loads over public HTTPS without login, app install, or geofencing.
- The page references the OnTime app or the developer name used in Google Play.
- The account deletion request path is prominent and easy to find.
- Users can request account deletion without being sent back to the app.
- The page explains what account data is deleted and what may be retained.
- The URL is entered in Play Console's account deletion or Data safety field.
- The final URL and evidence are recorded in this document.

## Final URL Record

- Final account deletion request URL: `TODO`
- Hosting owner: `TODO`
- Backend/privacy owner confirming deletion and retention behavior: `TODO`
- Play Console owner who entered the URL: `TODO`
- Date verified: `TODO`
- Evidence location: `TODO`

## Dependencies Before Publishing

- #439 must confirm backend account and data deletion behavior by provider and
  data type.
- #434 must approve privacy policy language so this page and the policy use the
  same deletion and retention claims.
- The support inbox, form backend, or request handling workflow must have an
  owner who can receive and fulfill deletion requests.

## Page Content Template

Replace every `TODO` before publishing.

```text
Title: Delete your OnTime account

OnTime users can request deletion of their app account and associated data from
this page. You do not need to install or open the OnTime app to submit a
request.

What we delete
- TODO: List account identity data deleted after #439 confirms server behavior.
- TODO: List schedule, preparation, notification, feedback, or profile data
  deleted after #439 confirms server behavior.

What we may retain
- TODO: List any data retained for legal, security, fraud prevention,
  regulatory, or operational reasons.
- TODO: State the retention period or review process for each retained data
  type.

How to request deletion
Option A: Submit the deletion request form below.
Option B: Email TODO_SUPPORT_EMAIL with the subject "OnTime account deletion".

Required information
- The email address or login provider used for the OnTime account.
- Any additional information required to verify the account owner.

What happens next
- We will verify account ownership before deleting the account.
- We will delete the account and associated data according to the privacy policy.
- TODO: State expected completion timing after owner/legal review.
- TODO: State whether the user receives a confirmation email.

Privacy policy
TODO_PRIVACY_POLICY_URL

Contact
TODO_SUPPORT_EMAIL
```

## Implementation Options

- Hosted form: preferred if the team has an existing website or backend form
  handler. The form must submit to an owned support or backend workflow.
- Support email page: acceptable if the page clearly shows the support email and
  deletion request instructions. The inbox must be monitored.
- Privacy policy anchor: acceptable only if the deletion section is prominent,
  directly linked, and provides a clear way to request deletion.

Do not use a PDF, login-only page, app deep link, editable public document, or
page that only tells users to reinstall/open the app.

## Verification Checklist

- [ ] Open the URL in a private/incognito browser while signed out.
- [ ] Confirm the URL uses HTTPS and does not redirect to login.
- [ ] Confirm the page references OnTime or the Google Play developer name.
- [ ] Confirm the deletion request path is visible without searching through
      unrelated content.
- [ ] Submit a test request using a test account or staging support workflow.
- [ ] Confirm the request reaches the responsible owner or backend system.
- [ ] Confirm the page deletion/retention text matches #439 and #434.
- [ ] Enter the URL in Play Console.
- [ ] Save a screenshot or note showing the Play Console field value.
- [ ] Replace the `TODO` values in the final URL record above.

## Human Tasks Remaining

1. Backend/privacy owner: complete #439 and provide final deletion and retention
   language.
2. Product/legal owner: approve privacy policy text in #434.
3. Web/backend owner: host a public HTTPS deletion request page or form using
   the approved language.
4. Support owner: confirm the receiving workflow is monitored and deletion
   requests can be fulfilled.
5. Play Console owner: enter the final URL in the required account deletion or
   Data safety field.
6. Release owner: update the final URL record and attach evidence before
   closing #440.
