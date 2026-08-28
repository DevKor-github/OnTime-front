---
status: accepted
---

# Default to private notification content

Every new Local Profile will use Private Notification Content for lock-screen Schedule Notification and alarm presentation. The default visible text will identify OnTime and the preparation prompt without revealing the Schedule name, Place, note, Preparation, or Preparation Step. A user may explicitly enable Detailed Notification Content, which may reveal only the Schedule name and, when different from the current device zone, its original Schedule Time Zone; Place, note, and preparation details remain excluded. Opening either mode will route to full information only through the operating system's device access control. The selected mode is a durable preference included in OnTime Backup. Always displaying the current Schedule title was rejected because platform notification storage and lock-screen presentation sit outside the encrypted Local Data Store, while removing all useful detail permanently was rejected in favor of an explicit user choice.
