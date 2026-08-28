---
status: accepted
---

# Use encrypted Drift as the local data source

Every item of Durable OnTime Data will use one encrypted Drift database as its authoritative Local Data Store. Domain repository contracts remain the application boundary, but their product implementations will use only local DAOs and database watch streams; remote data sources, remote models, Dio clients, authentication tokens, and server synchronization paths will be removed from the product runtime. Durable preferences will move into the same database so backup, restore, migration, and reset can operate on one consistent boundary. SharedPreferences or equivalent storage may hold only Reconstructible App State, while the Installation Data Key remains in device-bound secure storage and operating-system delivery registrations remain platform-owned projections rebuilt from the database. Keeping multiple persistence authorities was rejected because it permits partial backups, conflicting reads, and non-atomic restore or reset behavior. This decision increases the scope of the local schema and migrations but makes offline ownership explicit and testable.
