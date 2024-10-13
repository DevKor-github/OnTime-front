import { Model } from "@nozbe/watermelondb";
import { field, text, date, relation } from '@nozbe/watermelondb/decorators';


class Preparation_user extends Model {
    static table = 'preparation_users'

    static associations = {
        users: { type: 'belongs_to', foreignKey: 'user_id' },
    }

    @field('preparation_id') preparationId;
    @field('user_id') userId;
    @text('preparation_name') preparationName;
    @field('preparation_time') preparationTime;
    @field('order') order;

    @relation('users', 'user_id') user;
}

export default Preparation_user