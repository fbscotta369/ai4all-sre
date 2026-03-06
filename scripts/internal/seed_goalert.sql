-- GoAlert Admin Seeding Script
-- Standardizes the admin user to 'admin' / 'admin123'

DO $$
DECLARE
    v_admin_id UUID := '00000000-0000-0000-0000-000000000001';
    v_policy_id UUID := '00000000-0000-0000-0000-000000000010';
    v_service_id UUID := '00000000-0000-0000-0000-000000000020';
    v_rotation_id UUID := '00000000-0000-0000-0000-000000000030';
    v_schedule_id UUID := '00000000-0000-0000-0000-000000000040';
    v_integration_token UUID := 'eb5f27f0-d62f-4c54-99a4-7d3be96fa943';
BEGIN
    -- 1. Insert user if not exists
    IF NOT EXISTS (SELECT 1 FROM users WHERE id = v_admin_id) THEN
        INSERT INTO users (id, name, role, email, bio)
        VALUES (v_admin_id, 'Admin', 'admin', 'admin@example.com', 'System Administrator');
        RAISE NOTICE 'User admin created.';
    ELSE
        RAISE NOTICE 'User admin already exists.';
    END IF;

    -- 2. Insert auth_basic_user if not exists
    IF NOT EXISTS (SELECT 1 FROM auth_basic_users WHERE user_id = v_admin_id) THEN
        INSERT INTO auth_basic_users (user_id, username, password_hash)
        VALUES (v_admin_id, 'admin', '$2b$12$sH.HE0ZxAr2k/OkiXmLrMeSa77jKhqSx5shk1N5IVQ2rey7q9OapK');
        RAISE NOTICE 'Auth Basic User admin created.';
    ELSE
        UPDATE auth_basic_users SET password_hash = '$2b$12$sH.HE0ZxAr2k/OkiXmLrMeSa77jKhqSx5shk1N5IVQ2rey7q9OapK' WHERE user_id = v_admin_id;
        RAISE NOTICE 'Auth Basic User admin password updated.';
    END IF;

    -- 3. Insert auth_subject if not exists
    IF NOT EXISTS (SELECT 1 FROM auth_subjects WHERE user_id = v_admin_id AND provider_id = 'basic') THEN
        INSERT INTO auth_subjects (user_id, provider_id, subject_id)
        VALUES (v_admin_id, 'basic', 'admin');
        RAISE NOTICE 'Auth Subject admin created.';
    END IF;

    -- 4. Seed SRE Infrastructure (Policies & Services)
    -- Insert Escalation Policy
    IF NOT EXISTS (SELECT 1 FROM escalation_policies WHERE name = 'SRE-Critical') THEN
        INSERT INTO escalation_policies (id, name, description)
        VALUES (v_policy_id, 'SRE-Critical', 'Critical alerts for the SRE lab');
        RAISE NOTICE 'Escalation Policy SRE-Critical created.';
    ELSE
        SELECT id INTO v_policy_id FROM escalation_policies WHERE name = 'SRE-Critical';
    END IF;

    -- Insert Service
    IF NOT EXISTS (SELECT 1 FROM services WHERE name = 'Online-Boutique') THEN
        INSERT INTO services (id, name, description, escalation_policy_id)
        VALUES (v_service_id, 'Online-Boutique', 'Main microservices demo application', v_policy_id);
        RAISE NOTICE 'Service Online-Boutique created.';
    ELSE
        SELECT id INTO v_service_id FROM services WHERE name = 'Online-Boutique';
    END IF;

    -- Insert Integration Key
    IF NOT EXISTS (SELECT 1 FROM integration_keys WHERE id = v_integration_token) THEN
        INSERT INTO integration_keys (id, name, type, service_id)
        VALUES (v_integration_token, 'AlertManager', 'generic', v_service_id);
        RAISE NOTICE 'Integration Key AlertManager created.';
    END IF;

    -- 5. Seed Rotations and Schedules
    -- Insert Rotation
    IF NOT EXISTS (SELECT 1 FROM rotations WHERE id = v_rotation_id) THEN
        INSERT INTO rotations (id, name, description, type, start_time, shift_length, time_zone)
        VALUES (v_rotation_id, 'SRE Weekly Rotation', 'Primary SRE on-call rotation', 'weekly', now(), 1, 'America/New_York');
        RAISE NOTICE 'Rotation SRE Weekly Rotation created.';
    END IF;

    -- Insert Rotation Participant (Admin)
    IF NOT EXISTS (SELECT 1 FROM rotation_participants WHERE rotation_id = v_rotation_id AND user_id = v_admin_id) THEN
        INSERT INTO rotation_participants (id, rotation_id, user_id, position)
        VALUES (gen_random_uuid(), v_rotation_id, v_admin_id, 0);
        RAISE NOTICE 'Admin added to SRE Weekly Rotation.';
    END IF;

    -- Insert Schedule
    IF NOT EXISTS (SELECT 1 FROM schedules WHERE id = v_schedule_id) THEN
        INSERT INTO schedules (id, name, description, time_zone)
        VALUES (v_schedule_id, 'SRE Primary Schedule', 'Main schedule for SRE', 'America/New_York');
        RAISE NOTICE 'Schedule SRE Primary Schedule created.';
    END IF;

    -- Link Escalation Policy to Schedule (Step 0)
    IF NOT EXISTS (SELECT 1 FROM escalation_policy_steps WHERE escalation_policy_id = v_policy_id) THEN
        INSERT INTO escalation_policy_steps (id, escalation_policy_id, step_number, delay)
        VALUES ('00000000-0000-0000-0000-000000000050', v_policy_id, 0, 15);
        
        INSERT INTO escalation_policy_actions (id, escalation_policy_step_id, schedule_id)
        VALUES (gen_random_uuid(), '00000000-0000-0000-0000-000000000050', v_schedule_id);
    END IF;

END $$;
