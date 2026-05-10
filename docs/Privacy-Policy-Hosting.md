# Privacy Policy Hosting

Use this checklist to complete release issue #435 after the privacy policy text
from #434 is approved.

## Current Status

- Final privacy policy URL: `TBD`
- Hosting status: blocked until #434 provides approved policy text.
- Release owner: `TBD`
- Hosting owner: `TBD`
- Last validation date: `TBD`

Do not mark #435 complete until the final URL is active, public, and recorded
below.

## Hosting Requirements

- Host the approved policy at a public `https://` URL.
- Serve the policy as a normal web page, not as a PDF or downloadable file.
- Do not require login, app installation, team membership, or special network
  access.
- Do not publish it as a publicly editable document.
- Do not geofence or otherwise restrict access by country, region, device, or
  account.
- Keep the URL stable enough to use in the Google Play privacy policy field and
  in the app.

## Recommended Hosting Flow

1. Confirm #434 is complete and the policy text has product/legal approval.
2. Choose the final hosting surface, such as the product website or another
   owner-managed static site.
3. Publish the approved text as a standalone HTML page.
4. Validate the URL using the checklist below.
5. Record the final URL in this document, comment it on #435, and use the same
   URL for #436 and #437.

## Validation Checklist

- [ ] The URL starts with `https://`.
- [ ] A private/incognito browser session can open the page without signing in.
- [ ] `curl -I <final-url>` returns a successful HTTP status.
- [ ] The response is a web page and not a PDF or file download.
- [ ] The page is read-only for public visitors.
- [ ] The page is reachable from a non-team network.
- [ ] The page is not blocked by country, account, or device restrictions.
- [ ] The visible page title clearly identifies it as OnTime's privacy policy.
- [ ] The page content exactly matches the approved policy text from #434.
- [ ] The final URL is recorded in this document and in the #435 issue thread.

## Evidence Form

Fill this out when the page is live.

| Field | Value |
| --- | --- |
| Final privacy policy URL | `TBD` |
| Approved policy source | `#434` |
| Hosting surface | `TBD` |
| Release owner | `TBD` |
| Hosting owner | `TBD` |
| Validation date | `TBD` |
| HTTP status from `curl -I` | `TBD` |
| Browser validation notes | `TBD` |

## Handoff To Follow-Up Issues

- #436: add the final URL as the in-app privacy policy link.
- #437: enter the final URL in the Google Play Console privacy policy field.
- #441: check Data safety answers against the approved policy and hosted page.
