# Recovery, local data, and privacy visual review — 2026-09-25

Source file: `FIdR6bUMHScn9FWbwqrBsA`. All listed nodes were fetched with fresh high-fidelity design context and screenshots on 2026-09-25; source exports are separate from Flutter goldens. The comparison viewport is iOS 390×844, safe area top44/bottom21, Korean, text scale1.

## Source and capture inventory

| Figma node | Source export | SHA-256 | Flutter golden |
| --- | --- | --- | --- |
| `1957:11762` | `docs/design/review/figma/recovery-v3.png` | `0458b76579f000c3ed4b40059836b04ed35e38797caddca79477b47a75c73ea4` | `test/goldens/goldens/recovery_default_390x844.png` |
| `2003:12059` | `docs/design/review/figma/recovery-confirm-v3.png` | `ce978101bf343b568497e4c381a9e461abfbc767a50cda7268af28a7231db784` | `test/goldens/goldens/recovery_reset_confirmation_390x844.png` |
| `2005:12036` | `docs/design/review/figma/recovery-busy.png` | `93b54f8e6116d4d793d98106eb180ba920109a8f09046804a0fe2bdc2e7083d3` | `test/goldens/goldens/recovery_busy_390x844.png` |
| `1963:11762` | `docs/design/review/figma/reset-complete-v3.png` | `f98c8ab46909ad90ea9a602c8b768a7bd78fd819bb18f1bdc4f70a086230fd01` | `test/goldens/goldens/reset_complete_390x844.png` |
| `1950:11759` | `docs/design/review/figma/privacy-v3.png` | `88f84355c58e153300ccd4cce29c235c6fa3d05309fde7ba1eed99c04a6e94a5` | `test/goldens/goldens/privacy_policy_390x844.png` |
| `1978:11791` | `docs/design/review/figma/my-data-restore-preview.png` | `ffb62bd9764f8897e14d95f6f12334fd0be6f8ec0a30f31c615fd37ad68a5689` | `test/goldens/goldens/my_data_restore_preview_390x844.png` |
| `1979:11816` | `docs/design/review/figma/my-data-password-create.png` | `7e04e15b88d878162767d910c9d45f3703a2fbe6bf27d56522204cef66abb04b` | `test/goldens/goldens/my_data_password_create_390x844.png` |
| `1980:11841` | `docs/design/review/figma/my-data-password-input.png` | `94dd76f87a6a7fe77bd9672bdb645f52aa91700e48b2eeab101fbf2f4507f0c1` | `test/goldens/goldens/my_data_password_input_390x844.png` |
| `1981:11866` | `docs/design/review/figma/my-data-password-invalid.png` | `de016130f45b290c63baddad21479e1ed2b65de2701be604bd8432c55d67ec9f` | `test/goldens/goldens/my_data_password_invalid_390x844.png` |
| `1982:11891` | `docs/design/review/figma/my-data-password-mismatch.png` | `894f3c951dfcb852e4f42b96c40cd19586434ac3eecda4aad3f8b5211f7f4621` | `test/goldens/goldens/my_data_password_mismatch_390x844.png` |

The same `2003:12059` confirmation is used by My Data; its route capture is `test/goldens/goldens/my_data_reset_confirmation_390x844.png`.

## Implementation and comparison

- Recovery restores the exact 68×68 warning SVG, 22×22 information SVG, 352px content width, notice at (19,360), retry at y457, and fallback panel at y578. Both actions have 44px touch targets. Retry dispatches the existing auth retry event; reset still requires explicit confirmation.
- Reset confirmation uses the exact 47×47 destructive-warning and 22×22 information SVGs. Consequences start at (19,254); external-backup notice starts at (19,386); cancel/delete actions sit at y742. Both My Data and recovery open this shared screen.
- Busy recovery uses the exact 40×40 spinner artwork inside a 47px slot, heading at y397, disabled 356×44 actions at y702/y756. The spinner animates in production; the golden fixes its animation phase. A failed reset clears busy state and presents an error.
- Reset completion restores the exact 69×69 success and 23×23 outlined-information artwork. The final action remains at y754 with 50px height. The app retains required restart guidance after storage has been closed.
- Privacy uses the source 358px card grid at x16, first card y169, 14px inner padding, 16px section-number column, 12px gutter, six complete selectable sections, and scrollable large text.
- Password creation, restore password, invalid-length, mismatch, and restore preview are compared with all five fresh source exports. The 277px card at y352 is preserved; the primary action now uses the source #4F69DF through the existing scoped RefreshTheme, without changing global button styling. Secure inputs, 15–128 character validation, mismatch protection, cancellation, preview metadata, keyboard and 2× text behavior remain tested.

## Explicit runtime and source exceptions

- Native status bar and home indicator are operating-system UI and are excluded from app goldens.
- Bundled Pretendard remains the app font; Figma uses Noto Sans KR/IBM Plex Sans KR on these screens. Glyph shape and line wrapping differ, notably one line of the privacy backup section and password bullets. Cards grow naturally at larger text sizes rather than clipping the fixed Figma frames.
- Recovery and reset-complete are terminal storage states: their Figma back chevron has no valid destination, so the app omits it. Confirmation and privacy have a real 44px back control. The privacy source has a 37px header; the app keeps a 44px touch target and compensates introductory spacing to retain the first card at y169.
- The Figma recovery buttons are 43px/42px; the app uses 44px accessibility targets and compensates the adjacent gaps.
- After destructive reset, the database, secure key, and services are closed. Figma says “시작하기” and claims immediate restart; app keeps “다시 시작 안내” and explains a full process restart. The action displays guidance instead of accessing closed storage or bypassing initialization. This is a deliberate lifecycle requirement, not unfinished layout work.
- The five Figma My Data overlays contain a Restore-row icon/text overlap and a Reset-row label copied from backup export. Flutter retains correct current row labels, icons, and nonoverlapping layout underneath the scrim.
- Password fields retain actual secure TextField behavior, focus, keyboard handling, and scalable text; the mockup’s literal bullet strings are not used as fake fields.

## Asset verification

All added SVGs are nonempty files downloaded from the specific Figma context asset URLs. Original root dimensions are preserved at the callsites. Existing recovery_warning.svg and reset_success.svg match the fresh downloaded source byte-for-byte. The busy spinner is stored separately because its fresh source hash differs from the previous generic spinner.

- `assets/design/recovery_warning.svg` — SHA-256 `79f8587b1905dcf7a17eea7d1876d7222ea1dc5f08193464d08dbceed3b8144e`
- `assets/design/reset_success.svg` — SHA-256 `6523bd1c81ab2cf36aa8522260900bc226701babb6304d17c2f9d758f8b3f587`
- `assets/design/information_filled.svg` — SHA-256 `af35a5afb451a5cc45b1e560d2c6922897227b119e6d09ce04e74c80ff4b491a`
- `assets/design/information_outline.svg` — SHA-256 `d32455d3d0aa53f71266ea404872bfc892c258553f649d6cedd00c56d7bebcdb`
- `assets/design/destructive_warning.svg` — SHA-256 `5e7479a845a8961b1e76d60f52270fafed5f77657c266707b6d33e5bc6c017f7`
- `assets/design/recovery_spinner.svg` — SHA-256 `3435d4eaf4260f838229014a4297393e60f3c275b299191560fc14bb99516790`

## Verification

Focused command: `flutter test --no-pub --concurrency=1 --update-goldens test/presentation/startup/local_data_recovery_visual_test.dart test/presentation/startup/local_data_reset_complete_visual_test.dart test/presentation/my_page/privacy_policy_screen_visual_test.dart test/presentation/my_page/my_data_screen_visual_test.dart`. Focused run: **31 tests passed**. The recovery/My Data/privacy cases passed again in the combined focused run after the header chevron refinement. Fresh captures were visually inspected against the source images. Final assessment is source-reviewed with the explicit font, platform and storage-lifecycle exceptions above; it is not a claim of pixel-identical fonts. The parent task records the final full-suite and native backup verification.

Additional coverage: exact notice positions, destructive-screen placement, cancel leaves data untouched, retry behavior, busy disabled actions/reset failure, restart guidance, six privacy sections/2× scrolling, password validation/cancel, restoration preview cancellation, keyboard/large text, and iOS tap/label checks.
