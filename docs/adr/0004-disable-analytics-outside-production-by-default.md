# Disable Analytics Outside Production By Default

Product Usage Events will be sent to the Analytics Provider only for production builds by default, with any development or staging collection requiring an explicit override. This prevents local development, tests, Widgetbook, and manual QA from polluting production funnels, debugging signals, and experiment data.
