# Sync Analytics Preference Across Signed-In Devices

The Analytics Preference is installation-scoped before sign-in and account-scoped after sign-in, so a signed-in user's opt-out should apply across their devices. This requires a backend-supported account preference rather than relying only on local app storage, because optional analytics must stop consistently once the user disables Help Improve OnTime.
