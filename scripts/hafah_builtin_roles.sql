DO $$
BEGIN
    CREATE ROLE hafah_owner LOGIN INHERIT IN ROLE hive_applications_group;
    GRANT hafah_owner TO hive;
    EXCEPTION WHEN DUPLICATE_OBJECT THEN
    RAISE NOTICE 'hafah_owner role already exists';
END
$$;

DO $$
BEGIN
    CREATE ROLE hafah_user LOGIN INHERIT IN ROLE hive_applications_group;
    GRANT hafah_user TO hive;
    EXCEPTION WHEN DUPLICATE_OBJECT THEN
    RAISE NOTICE 'hafah_user role already exists';
END
$$;
