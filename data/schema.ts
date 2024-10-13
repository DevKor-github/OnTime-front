import { appSchema, tableSchema } from "@nozbe/watermelondb";
import "reflect-metadata";
import { injectable } from "inversify";

export default appSchema({
    version: 1,
    tables: [
        // Schedule table
        tableSchema({
            name: "schedule",
            columns: [
                { name: "schedule_id", type: "number" },
                { name: "user_id", type: "number" },
                { name: "place_id", type: "number" },
                // datetime
                { name: "schedule_time_at", type: "number" },
                // time
                { name: "move_time", type: "number" },
                { name: "is_change", type: "boolean" },
                { name: "is_started", type: "boolean" },
                // time
                { name: "schedule_spare_time", type: "number" },
                { name: "schedule_note", type: "string" },
            ],
        }),
        // Place table
        tableSchema({
            name: "place",
            columns: [
                { name: "place_id", type: "number" },
                // varchar(30)
                { name: "place", type: "string" },
            ],
        }),

        // Preparation_schedule
        tableSchema({
            name: "preparation_schedule",
            columns: [
                { name: "preparation_id", type: "number" },
                { name: "schedule_id", type: "number" },
                // varchar(30)
                { name: "preparation_name", type: "string" },
                // time
                { name: "preparation_time", type: "number" },
                { name: "order", type: "number" },
            ],
        }),

        // User
        tableSchema({
            name: "user",
            columns: [
                { name: "user_id", type: "number" },
                // varchar(320)
                { name: "email", type: "string" },
                // varchar(30)
                { name: "password", type: "string" },
                // varchar(30)
                { name: "name", type: "string" },
                // time
                { name: "spare_time", type: "number" },
                { name: "note", type: "string" },
                // float
                { name: "score", type: "number" },
            ],
        }),

        // Preparation_user
        tableSchema({
            name: "preparation_user",
            columns: [
                { name: "preparation_id", type: "number" },
                { name: "user_id", type: "number" },
                // varchar(30)
                { name: "preparation_name", type: "string" },
                // time
                { name: "preparation_time", type: "number" },
                { name: "order", type: "number" },
            ],
        }),
    ],
});
