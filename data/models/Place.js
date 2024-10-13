import { Model } from "@nozbe/watermelondb";
import { field, text, relation } from '@nozbe/watermelondb/decorators';


class Place extends Model {
    static table = 'places'

    static associations = {
        schedules: { type: 'has_one', foreignKey: 'place_id' },
    }

    @field("place_id") placeId;
    @text("place") place;

    @relation('places', 'place_id') place;

}

export default Place