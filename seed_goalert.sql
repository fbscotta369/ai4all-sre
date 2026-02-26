-- GoAlert Admin Seeding Script
-- Standardizes the admin user to 'admin' / 'admin123'

DO $$
DECLARE
    admin_id UUID := '00000000-0000-0000-0000-000000000001';
    policy_id UUID := '00000000-0000-0000-0000-000000000010';
    service_id UUID := '00000000-0000-0000-0000-000000000020';
    integration_token UUID := 'eb5f27f0-d62f-4c54-99a4-7d3be96fa943';
BEGIN
    -- 1. Insert user if not exists
    IF NOT EXISTS (SELECT 1 FROM users WHERE id = admin_id) THEN
        INSERT INTO users (id, name, role, email, bio)
        VALUES (admin_id, 'Admin', 'admin', 'admin@example.com', 'System Administrator');
        RAISE NOTICE 'User admin created.';
    ELSE
        RAISE NOTICE 'User admin already exists.';
    END IF;

    -- 2. Insert auth_basic_user if not exists
    -- Password hash for 'admin123'
    IF NOT EXISTS (SELECT 1 FROM auth_basic_users WHERE user_id = admin_id) THEN
        INSERT INTO auth_basic_users (user_id, username, password_hash)
        VALUES (admin_id, 'admin', '$2b$12$sH.HE0ZxAr2k/OkiXmLrMeSa77jKhqSx5shk1N5IVQ2rey7q9OapK');
        RAISE NOTICE 'Auth Basic User admin created.';
    ELSE
        UPDATE auth_basic_users SET password_hash = '$2b$12$sH.HE0ZxAr2k/OkiXmLrMeSa77jKhqSx5shk1N5IVQ2rey7q9OapK' WHERE user_id = admin_id;
        RAISE NOTICE 'Auth Basic User admin password updated.';
    END IF;

    -- 3. Insert auth_subject if not exists
    IF NOT EXISTS (SELECT 1 FROM auth_subjects WHERE user_id = admin_id AND provider_id = 'basic') THEN
        INSERT INTO auth_subjects (user_id, provider_id, subject_id)
        VALUES (admin_id, 'basic', 'admin');
        RAISE NOTICE 'Auth Subject admin created.';
    END IF;

    -- 4. Seed SRE Infrastructure (Policies & Services)
    -- Insert Escalation Policy
    IF NOT EXISTS (SELECT 1 FROM escalation_policies WHERE name = 'SRE-Critical') THEN
        INSERT INTO escalation_policies (id, name, description)
        VALUES (policy_id, 'SRE-Critical', 'Critical alerts for the SRE lab');
        RAISE NOTICE 'Escalation Policy SRE-Critical created.';
    ELSE
        SELECT id INTO policy_id FROM escalation_policies WHERE name = 'SRE-Critical';
    END IF;

    -- Insert Service
    IF NOT EXISTS (SELECT 1 FROM services WHERE name = 'Online-Boutique') THEN
        INSERT INTO services (id, name, description, escalation_policy_id)
        VALUES (service_id, 'Online-Boutique', 'Main microservices demo application', policy_id);
        RAISE NOTICE 'Service Online-Boutique created.';
    ELSE
        SELECT id INTO service_id FROM services WHERE name = 'Online-Boutique';
    END IF;

    -- Insert Integration Key (Crucial: Token must match observability.tf)
    IF NOT EXISTS (SELECT 1 FROM integration_keys WHERE id = integration_token) THEN
        INSERT INTO integration_keys (id, name, type, service_id)
        VALUES (integration_token, 'AlertManager', 'generic', service_id);
        RAISE NOTICE 'Integration Key AlertManager created.';
    END IF;
END $$;
