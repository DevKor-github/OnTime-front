---
status: accepted
---

# Normalize and bound backup passwords

Before Argon2id key derivation, OnTime will normalize a Backup Password to Unicode NFC and encode the resulting string as UTF-8 identically on Android and iOS. The normalized password must contain 15 through 128 Unicode code points and no more than 1,024 UTF-8 bytes. Unicode characters, ASCII spaces, symbols, and paste input are accepted; case, repeated spaces, and leading or trailing spaces are preserved, and no uppercase, digit, symbol, or other composition rule is imposed. Export requires two matching prepared entries, while restore processes the complete entry once. The app will not persist, autofill, hint, recover, or log the password and will clear native password and derived-key buffers immediately after the operation, with best-effort lifetime minimization for managed strings that cannot be deterministically wiped. NFC provides stable cross-platform treatment for canonically equivalent Unicode input as recommended by [RFC 8265](https://www.rfc-editor.org/rfc/rfc8265.html) and [NIST SP 800-63B-4](https://pages.nist.gov/800-63-4/sp800-63b.html). Trimming, lossy character mapping, short-password acceptance, and mandatory character classes were rejected because they either make equivalent cross-platform input unreliable, weaken offline-file protection, or reduce passphrase usability.
