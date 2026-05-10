# Account Deletion Request URL

Use this handoff when creating the public account deletion request URL required
for Google Play. This issue is not complete until the final hosted URL works,
is entered in Play Console, and is recorded below.

Issue: #440
Parent track: #464
Status: complete. URL is public, request workflow is confirmed, and the delete
account URL field is saved in the Play Console Data safety draft.

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

- Final account deletion request URL: `https://ontime-back.duckdns.org/account-deletion`
- Hosting owner: Backend owner
- Backend/privacy owner confirming deletion and retention behavior: Backend owner
- Play Console owner who entered the URL: `jjoonleo@gmail.com`
- Date verified: `2026-05-10`
- Evidence location: #440 issue comments with `curl` verification summary and
  Play Console save note

## Dependencies Before Publishing

- #439 must confirm backend account and data deletion behavior by provider and
  data type.
- #434 must approve privacy policy language so this page and the policy use the
  same deletion and retention claims.
- The support inbox, form backend, or request handling workflow must have an
  owner who can receive and fulfill deletion requests.

## Page Content Template

Use the following content expectations when reviewing the hosted page. Replace
every remaining `TODO` before closing #440.

```text
Title: Delete your OnTime account

OnTime users can request deletion of their app account and associated data from
this page. You do not need to install or open the OnTime app to submit a
request.

What we delete
- OnTime deletes the local account and associated app data, including schedules,
  preparation data, notification schedules, user settings, alarm settings, alarm
  status, device records, FCM tokens, and session tokens.

What we may retain
- Optional account deletion feedback may be retained for up to 1 year for
  service quality review and deletion-related support issues.
- Operational logs, monitoring records, and security records may be retained for
  up to 90 days for service operation, debugging, security, and abuse
  prevention.
- Backup copies containing deleted account data are removed according to normal
  backup rotation and retained for no longer than 30 days.
- Data may be retained longer only when required by law or an active security
  investigation.

How to request deletion
Option A: Submit the deletion request form below.
Option B: Email jjoonleo@gmail.com with the subject "OnTime account deletion".

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
jjoonleo@gmail.com
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

- [x] Open `https://ontime-back.duckdns.org/account-deletion` in a
      private/incognito browser while signed out.
- [x] Confirm the URL uses HTTPS and does not redirect to login.
- [x] Confirm the page references OnTime or the Google Play developer name.
- [x] Confirm the deletion request path is visible without searching through
      unrelated content.
- [x] Submit a test request using a test account or staging support workflow.
- [x] Confirm the request reaches the responsible owner or backend system.
- [x] Confirm the page deletion/retention text matches #439 and #434.
- [x] Enter the URL in Play Console.
- [x] Save a screenshot or note showing the Play Console field value.
- [x] Replace the remaining `TODO` values in the final URL record above.

## Human Tasks Remaining

1. Backend/privacy owner: confirm the hosted page uses the final deletion and
   retention language from #434.
2. Product/legal owner: approve privacy policy text in #434.
3. Web/backend owner: verify the public HTTPS deletion request page or form
   remains available at `https://ontime-back.duckdns.org/account-deletion`.
4. Play Console owner: continue #441 separately to complete the full Data
   safety questionnaire before release submission.
