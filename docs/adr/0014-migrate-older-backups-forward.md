---
status: accepted
---

# Migrate older backups forward

Each OnTime Backup will declare a Backup Format Version independent of the app release and local database schema. Every current release must restore all older released backup formats by validating and migrating them forward before changing active data. A backup created by a newer unknown format will be rejected without mutation and the user will be told to update OnTime. This creates a long-lived maintenance obligation, but it preserves the usefulness of the user's only portable recovery artifact while allowing encryption and data schemas to evolve.
