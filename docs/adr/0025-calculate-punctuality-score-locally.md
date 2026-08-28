---
status: accepted
---

# Calculate punctuality score locally

OnTime will preserve the existing punctuality calculation as a Local Punctuality Score owned by the Local Data Store. Only On Time and Late Schedule Outcomes are eligible, and the score is the On Time count divided by all eligible outcomes since the latest Punctuality Score Reset, multiplied by 100; Abnormal outcomes are excluded, and a period with no eligible outcome is represented as not yet calculated rather than zero. Completing a Schedule and registering its score contribution will be one atomic local transaction, with an idempotency constraint ensuring that one Schedule contributes at most once. A Punctuality Score Reset starts a new aggregation period without deleting Schedules or outcomes, and deleting a completed Schedule does not retroactively decrement an already registered contribution. The aggregation basis and reset boundary are Durable OnTime Data included in OnTime Backup, while Local Data Reset removes them. Replacing the score with a new heuristic or continuing to depend on the server was rejected because the established user-visible rule can be reproduced deterministically offline.
