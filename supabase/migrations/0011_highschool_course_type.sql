-- 0011: Add highschool option to course_type enum

ALTER TYPE course_type ADD VALUE IF NOT EXISTS 'highschool';
