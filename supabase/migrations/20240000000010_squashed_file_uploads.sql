-- Drop existing tables and objects if they exist
DO $$ 
DECLARE
    table_exists boolean;
BEGIN
    -- Check if table exists first
    SELECT EXISTS (
        SELECT FROM pg_tables 
        WHERE schemaname = 'ai_chat_app_schema' 
        AND tablename = 'file_uploads'
    ) INTO table_exists;

    -- Only check for trigger if table exists
    IF table_exists THEN
        -- Drop trigger if it exists
        IF EXISTS (
            SELECT 1 FROM pg_trigger 
            WHERE tgname = 'tr_file_version'
            AND tgrelid = (
                SELECT oid FROM pg_class 
                WHERE relname = 'file_uploads' 
                AND relnamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'ai_chat_app_schema')
            )
        ) THEN
            DROP TRIGGER tr_file_version ON ai_chat_app_schema.file_uploads;
        END IF;
    END IF;

    -- Drop functions if they exist
    DROP FUNCTION IF EXISTS ai_chat_app_schema.set_file_version();
    DROP FUNCTION IF EXISTS ai_chat_app_schema.get_next_file_version();

    -- Drop table if it exists
    IF table_exists THEN
        DROP TABLE ai_chat_app_schema.file_uploads;
    END IF;
END $$;

-- Create the file_uploads table with all required columns and constraints
CREATE TABLE ai_chat_app_schema.file_uploads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    chat_id UUID NOT NULL REFERENCES ai_chat_app_schema.chats(id) ON DELETE CASCADE,
    bucket_id TEXT NOT NULL DEFAULT 'ai_chat_app_storage',
    storage_path TEXT NOT NULL,
    filename TEXT NOT NULL,
    original_name TEXT NOT NULL,
    content_type TEXT NOT NULL,
    size INTEGER NOT NULL,
    url TEXT NOT NULL,
    version INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,

    -- Composite unique constraints
    CONSTRAINT file_uploads_unique_version UNIQUE (bucket_id, storage_path, version),
    CONSTRAINT file_uploads_unique_per_chat UNIQUE (user_id, chat_id, filename, version)
);

-- Enable RLS
ALTER TABLE ai_chat_app_schema.file_uploads ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for file_uploads
CREATE POLICY "Users can insert their own files"
ON ai_chat_app_schema.file_uploads
FOR INSERT TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can view their own files"
ON ai_chat_app_schema.file_uploads
FOR SELECT TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own files"
ON ai_chat_app_schema.file_uploads
FOR DELETE TO authenticated
USING (auth.uid() = user_id);

-- Create indexes for better performance
CREATE INDEX file_uploads_user_id_idx ON ai_chat_app_schema.file_uploads(user_id);
CREATE INDEX file_uploads_chat_id_idx ON ai_chat_app_schema.file_uploads(chat_id);
CREATE INDEX file_uploads_created_at_idx ON ai_chat_app_schema.file_uploads(created_at);
CREATE INDEX file_uploads_bucket_path_idx ON ai_chat_app_schema.file_uploads(bucket_id, storage_path);

-- Create versioning function
CREATE OR REPLACE FUNCTION ai_chat_app_schema.get_next_file_version(
    p_bucket_id TEXT,
    p_storage_path TEXT
) RETURNS INTEGER AS $$
DECLARE
    next_version INTEGER;
BEGIN
    SELECT COALESCE(MAX(version), 0) + 1
    INTO next_version
    FROM ai_chat_app_schema.file_uploads
    WHERE bucket_id = p_bucket_id 
    AND storage_path = p_storage_path;
    
    RETURN next_version;
END;
$$ LANGUAGE plpgsql;

-- Create version trigger function
CREATE OR REPLACE FUNCTION ai_chat_app_schema.set_file_version()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.version = 1 THEN  -- Only auto-increment if not explicitly set
        NEW.version := ai_chat_app_schema.get_next_file_version(NEW.bucket_id, NEW.storage_path);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create version trigger
CREATE TRIGGER tr_file_version
    BEFORE INSERT ON ai_chat_app_schema.file_uploads
    FOR EACH ROW
    EXECUTE FUNCTION ai_chat_app_schema.set_file_version();

-- Grant necessary permissions
GRANT ALL ON ai_chat_app_schema.file_uploads TO authenticated;
GRANT SELECT ON ai_chat_app_schema.file_uploads TO public;
GRANT ALL ON storage.objects TO authenticated;
GRANT SELECT ON storage.objects TO public;
GRANT ALL ON storage.buckets TO authenticated;
GRANT SELECT ON storage.buckets TO public; 