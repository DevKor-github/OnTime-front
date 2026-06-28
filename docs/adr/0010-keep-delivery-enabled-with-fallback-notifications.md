# Keep Delivery Enabled With Fallback Notifications

When exact alarm or AlarmKit permission is denied but notification fallback is available, OnTime will keep schedule notifications enabled and arm them through Fallback Notification delivery. Exact timing or AlarmKit recovery remains a non-blocking improvement path, while disabling schedule notifications is reserved for states where no native or fallback delivery path can currently notify the user.
