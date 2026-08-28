---
status: accepted
---

# Make the local-only cutover one-way

The product release that introduces Local-only OnTime will perform a one-way, idempotent cutover rather than ship dual server and local modes. It will remove Legacy Installation State, create a Local-only Cutover Marker only after cleanup succeeds, and then create a new Local Profile and encrypted Local Data Store. The encrypted store will use a file name and storage identity distinct from the legacy unencrypted `my_database` so a server-backed build cannot parse, migrate, or overwrite local-only data. Subsequent startup failure will enter Recovery Mode and will never reactivate login, remote data sources, or a server recovery path. Development may sequence the refactor internally, but the released artifact will contain no server/local feature flag or remote fallback, and app downgrade to a server-backed version after cutover is unsupported. Reusing the legacy database or retaining a reversible mode switch was rejected because older schema code and dormant network paths could corrupt the new store or silently break the Product Network Boundary.
