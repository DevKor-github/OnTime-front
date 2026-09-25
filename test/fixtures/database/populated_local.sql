-- Synthetic durable row images, independent of today's entity serializers.
INSERT INTO users(id,spare_time,note,is_onboarding_completed,eligible_outcome_count,on_time_outcome_count,alarms_enabled,alarm_offset_minutes,detailed_notification_content,data_revision,last_exported_revision,last_exported_at,first_durable_data_at,last_durable_data_at)
VALUES('local-profile',17,'합성 프로필  공백',1,4,3,1,-5,0,19,17,100,50,200);
INSERT INTO places(id,place_name) VALUES('place-a','집'),('place-b',' New York ');
INSERT INTO preparation_templates(id,template_name,created_at,updated_at) VALUES('template-a','아침 준비',100,150);
INSERT INTO preparation_template_steps(id,template_id,preparation_name,preparation_time,position) VALUES('ts-a','template-a','옷 입기',7,0),('ts-b','template-a','나가기',0,1);
INSERT INTO preparation_users(id,user_id,preparation_name,preparation_time,next_preparation_id) VALUES('pu-b','local-profile','마지막',0,NULL),('pu-a','local-profile','처음',11,'pu-b');
INSERT INTO schedules(id,place_id,schedule_name,time_zone_id,occurrence_offset_seconds,schedule_time,move_time,is_changed,is_started,schedule_spare_time,schedule_note,lateness_time,done_status,started_at,finished_at,preparation_mode,preparation_template_id,preparation_template_name,preparation_template_deleted,preparation_frozen,score_contribution_recorded)
VALUES('done','place-a','완료된 합성 일정','Asia/Seoul',NULL,'2026-01-01T09:15:00.000',13,1,1,0,NULL,4,'normalEnd',100,200,'custom','template-a','삭제된 원본 이름',1,1,1),
('future','place-b','중첩 시각 일정','America/New_York',-14400,'2030-11-03T01:30:00.000',9,0,0,NULL,' 두  공백 유지 ', -1,'notEnded',NULL,NULL,'default',NULL,NULL,0,0,0);
INSERT INTO preparation_schedules(id,schedule_id,preparation_name,preparation_time,next_preparation_id) VALUES('ps-b','done','종료 단계',0,NULL),('ps-a','done','첫 단계',12,'ps-b');
