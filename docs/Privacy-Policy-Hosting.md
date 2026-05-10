# Privacy Policy Hosting

Use this checklist to track release issue #435 and the hosted privacy policy URL
used by Play Console.

## Current Status

- Final privacy policy URL: `https://ontime-back.duckdns.org/privacy-policy`
- Hosting status: live and entered in Play Console on 2026-05-10.
- Release owner: `jjoonleo@gmail.com`
- Hosting owner: backend server owner
- Last validation date: 2026-05-10

The URL is active, public, recorded below, and saved in the Play Console Privacy
Policy page. Product/legal approval of the final policy text is tracked by #434.

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

- [x] The URL starts with `https://`.
- [x] A browser session can open the page without signing in.
- [x] `curl -L -D - <final-url>` returns a successful HTTP status.
- [x] The response is a web page and not a PDF or file download.
- [x] The page is read-only for public visitors.
- [x] The page is reachable from a non-team network.
- [x] The page is not blocked by country, account, or device restrictions.
- [x] The visible page title clearly identifies it as OnTime's privacy policy.
- [ ] The page content exactly matches the approved policy text from #434.
- [x] The final URL is recorded in this document and in the #435 issue thread.

## Evidence Form

Fill this out when the page is live.

| Field | Value |
| --- | --- |
| Final privacy policy URL | `https://ontime-back.duckdns.org/privacy-policy` |
| Approved policy source | `#434` |
| Hosting surface | OnTime backend server |
| Release owner | `jjoonleo@gmail.com` |
| Hosting owner | backend server owner |
| Validation date | 2026-05-10 |
| HTTP status from `curl -L -D -` | `HTTP/2 200`, `content-type: text/html` |
| Browser validation notes | Public Play Console URL saved in Privacy Policy page; page title is `OnTime Privacy Policy` and includes developer/entity, contact email, effective date, account deletion URL, and retention language. |

## Handoff To Follow-Up Issues

- #436: add the final URL as the in-app privacy policy link.
- #437: completed; the final URL is saved in the Google Play Console privacy policy field.
- #441: check Data safety answers against the approved policy and hosted page.
