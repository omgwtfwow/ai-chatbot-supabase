-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create schema if not exists (with isolation)
CREATE SCHEMA IF NOT EXISTS ai_chat_app_schema;

-- Revoke all privileges from public schema for isolation
REVOKE ALL ON SCHEMA ai_chat_app_schema FROM PUBLIC;

-- Grant specific privileges
GRANT USAGE ON SCHEMA ai_chat_app_schema TO authenticated, anon, service_role;
GRANT ALL ON SCHEMA ai_chat_app_schema TO postgres, supabase_admin;