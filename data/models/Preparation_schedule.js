import { Model } from "@nozbe/watermelondb";
import { field, text, relation } from '@nozbe/watermelondb/decorators';


class Preparation_schedule extends Model {
    static table = 'preparation_schedules'

    static associations = {
        schedules: { type: 'belongs_to', foreignKey: 'schedule_id' },
    }

    @field("preparation_id") preparationId;
    @field("schedule_id") scheduleId;
    @text("perparation_name") preparationName;
    @field("preparation_time") preparationTime;
    @field("order") order;

    @relation('schedules', 'schedule_id') schedule; 
}

export default Preparation_schedule