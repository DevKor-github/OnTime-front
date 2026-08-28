---
status: accepted
---

# Require a verified restore preview

Backup Restore will not replace active data immediately after file selection or password entry. OnTime will first decrypt the complete backup, authenticate its integrity, check its Backup Format Version, migrate it into a staging Local Data Store, and validate all represented data. Only then will it show a Restore Preview containing the Backup Cutoff, source app version, data categories and counts, and an explicit warning that the active Local Data Store will be replaced. Replacement requires a separate final user confirmation; cancellation removes staging data and leaves active data untouched. Preview metadata will remain inside the encrypted payload, while the plaintext envelope header will contain only the format identification and cryptographic parameters needed to derive a key and decrypt it. Immediate restore and plaintext descriptive metadata were rejected because they create avoidable overwrite and privacy risks.
