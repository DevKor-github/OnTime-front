# Retain De-Identified Historical Analytics After Account Deletion

When an account is deleted, OnTime will stop future user-linked Product Usage Events and clear the analytics user association, but historical Firebase Analytics data may be retained only in aggregate or de-identified form. This avoids promising database-style cascade deletion for provider-managed analytics exports while preserving product improvement, debugging and operations, and experimentation value.
