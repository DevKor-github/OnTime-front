import { Model } from "@nozbe/watermelondb";
import { field, text, date, children, relation } from '@nozbe/watermelondb/decorators';

class Schedule extends Model {
  static table = 'schedules'

  static associations = {
    places: { type: 'belongs_to', foreignKey: 'place_id' },
    users: { type: 'belongs_to', foreignKey: 'user_id' },
    preparation_schedules: { type: 'has_many', foreignKey: 'schedule_id' },

  }

  @field("schedule_id") scheduleId;
  @field("user_id") userId;
  @field("place_id") placeId;
  @date("schedule_time_at") scheduleTimeAt;
  @field("move_time") moveTime;
  @field("is_change") isChange;
  @field("is_started") isStarted;
  @field("schedule_spare_time") scheduleSpareTime;
  @text("schedule_note") scheduleNote;


  @relation('users', 'user_id') user; 
  @relation('places', 'place_id') place; 
  @children('preparation_schedules') preparation_schedules;  
}

export default Schedule