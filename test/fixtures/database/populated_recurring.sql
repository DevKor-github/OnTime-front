INSERT INTO preparation_definitions(id,owner_id,scope,name,created_at) VALUES('definition','series','recurring','반복 준비',100);
INSERT INTO preparation_definition_steps(id,definition_id,name,minutes,position) VALUES('definition-step','definition','알림  공백',0,0);
INSERT INTO recurring_schedule_segments(id,series_id,rule_json,schedule_json,preparation_id,from_slot,before_slot,created_at,preparation_not_before)
VALUES('root-segment','series','{"type":"synthetic-preserve","days":[1,3]}','{"note":"한글  원문"}','definition','2030-11-03T01:30:00.000',NULL,100,90);
INSERT INTO recurring_schedule_exclusions(segment_id,slot_key,ordinal) VALUES('root-segment','2030-11-10T01:30:00.000',2);
UPDATE schedules SET recurring_segment_id='root-segment',recurring_slot_key='2030-11-03T01:30:00.000',recurring_ordinal=1,recurring_overrides='note',preparation_definition_id='definition' WHERE id='future';
