import { Model } from "@nozbe/watermelondb";
import { field, text, children, relation } from '@nozbe/watermelondb/decorators';


class User extends Model {
    static table = 'users'

    static associations = {
        schedules: { type: 'has_many', foreignKey: 'user_id' },
        preparation_users: { type: 'has_many', foreignKey: 'user_id' },

    }

    @field("user_id") userId;
    @field("email") email;
    @field("password") password;
    @text("name") name;
    @field("spare_time") spareTime;
    @field("note") note;
    @field("score") score;

    @children('schedules') schedules;
    @children('preparation_users') preparation_users;
}

export default User