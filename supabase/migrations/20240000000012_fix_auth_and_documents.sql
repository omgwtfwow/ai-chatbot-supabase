-- First, let's fix the documents table to handle updates better
ALTER TABLE ai_chat_app_schema.documents 
DROP CONSTRAINT IF EXISTS documents_pkey CASCADE;

-- Recreate primary key with a more robust structure
ALTER TABLE ai_chat_app_schema.documents
ADD CONSTRAINT documents_pkey 
PRIMARY KEY (id, created_at);

-- Create function to get latest version
CREATE OR REPLACE FUNCTION ai_chat_app_schema.get_document_latest_version(doc_id UUID)
RETURNS TIMESTAMPTZ AS $$
BEGIN
    RETURN (
        SELECT MAX(created_at)
        FROM ai_chat_app_schema.documents
        WHERE id = doc_id
    );
END;
$$ LANGUAGE plpgsql;

-- Create function to handle document versioning
CREATE OR REPLACE FUNCTION ai_chat_app_schema.handle_document_version()
RETURNS TRIGGER AS $$
BEGIN
    -- If this is an update to an existing document
    IF EXISTS (
        SELECT 1 FROM ai_chat_app_schema.documents 
        WHERE id = NEW.id AND user_id = NEW.user_id
    ) THEN
        -- Insert as a new version instead of updating
        INSERT INTO ai_chat_app_schema.documents (
            id,
            user_id,
            title,
            content,
            created_at
        ) VALUES (
            NEW.id,
            NEW.user_id,
            NEW.title,
            NEW.content,
            NOW()
        );
        RETURN NULL; -- Prevent the original UPDATE
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for document versioning
DROP TRIGGER IF EXISTS document_version_trigger ON ai_chat_app_schema.documents;
CREATE TRIGGER document_version_trigger
    BEFORE UPDATE ON ai_chat_app_schema.documents
    FOR EACH ROW
    EXECUTE FUNCTION ai_chat_app_schema.handle_document_version();

-- Add RLS policies to ensure proper access
ALTER TABLE ai_chat_app_schema.documents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can insert their own documents" ON ai_chat_app_schema.documents;
CREATE POLICY "Users can insert their own documents"
    ON ai_chat_app_schema.documents
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can view their own documents" ON ai_chat_app_schema.documents;
CREATE POLICY "Users can view their own documents"
    ON ai_chat_app_schema.documents
    FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own documents" ON ai_chat_app_schema.documents;
CREATE POLICY "Users can update their own documents"
    ON ai_chat_app_schema.documents
    FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id);

-- Add function to get latest document version
CREATE OR REPLACE FUNCTION ai_chat_app_schema.get_latest_document(doc_id UUID, auth_user_id UUID)
RETURNS TABLE (
    id UUID,
    user_id UUID,
    title TEXT,
    content TEXT,
    created_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT d.id, d.user_id, d.title, d.content, d.created_at
    FROM ai_chat_app_schema.documents d
    WHERE d.id = doc_id
    AND d.user_id = auth_user_id
    AND d.created_at = ai_chat_app_schema.get_document_latest_version(d.id);
END;
$$ LANGUAGE plpgsql
SECURITY DEFINER;

-- Create indexes if they don't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_documents_user_id') THEN
        CREATE INDEX idx_documents_user_id ON ai_chat_app_schema.documents(user_id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_documents_created_at') THEN
        CREATE INDEX idx_documents_created_at ON ai_chat_app_schema.documents(created_at);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_documents_latest_version') THEN
        CREATE UNIQUE INDEX idx_documents_latest_version 
        ON ai_chat_app_schema.documents(id, user_id, created_at DESC);
    END IF;
END $$;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION ai_chat_app_schema.get_latest_document TO authenticated;
GRANT EXECUTE ON FUNCTION ai_chat_app_schema.get_document_latest_version TO authenticated; 