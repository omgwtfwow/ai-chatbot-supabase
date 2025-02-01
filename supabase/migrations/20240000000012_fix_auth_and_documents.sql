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

-- Drop all existing policies first
DO $$ 
BEGIN
    -- Drop document policies
    DROP POLICY IF EXISTS "Users can view own documents" ON ai_chat_app_schema.documents;
    DROP POLICY IF EXISTS "Users can create own documents" ON ai_chat_app_schema.documents;
    DROP POLICY IF EXISTS "Users can update own documents" ON ai_chat_app_schema.documents;
    DROP POLICY IF EXISTS "Users can delete own documents" ON ai_chat_app_schema.documents;
    DROP POLICY IF EXISTS "Users can insert their own documents" ON ai_chat_app_schema.documents;
    DROP POLICY IF EXISTS "Users can view their own documents" ON ai_chat_app_schema.documents;
    DROP POLICY IF EXISTS "Users can update their own documents" ON ai_chat_app_schema.documents;

    -- Drop chat policies
    DROP POLICY IF EXISTS "Users can view own chats" ON ai_chat_app_schema.chats;
    DROP POLICY IF EXISTS "Users can create own chats" ON ai_chat_app_schema.chats;
    DROP POLICY IF EXISTS "Users can update own chats" ON ai_chat_app_schema.chats;
    DROP POLICY IF EXISTS "Users can delete own chats" ON ai_chat_app_schema.chats;

    -- Drop message policies
    DROP POLICY IF EXISTS "Users can view messages from their chats" ON ai_chat_app_schema.messages;
    DROP POLICY IF EXISTS "Users can create messages in their chats" ON ai_chat_app_schema.messages;
    DROP POLICY IF EXISTS "Users can update messages in their chats" ON ai_chat_app_schema.messages;
    DROP POLICY IF EXISTS "Users can delete messages from their chats" ON ai_chat_app_schema.messages;

    -- Drop vote policies
    DROP POLICY IF EXISTS "Users can view votes from their chats" ON ai_chat_app_schema.votes;
    DROP POLICY IF EXISTS "Users can create votes in their chats" ON ai_chat_app_schema.votes;
    DROP POLICY IF EXISTS "Users can update votes in their chats" ON ai_chat_app_schema.votes;
    DROP POLICY IF EXISTS "Users can delete votes from their chats" ON ai_chat_app_schema.votes;

    -- Drop suggestion policies
    DROP POLICY IF EXISTS "Users can view own suggestions" ON ai_chat_app_schema.suggestions;
    DROP POLICY IF EXISTS "Users can create own suggestions" ON ai_chat_app_schema.suggestions;
    DROP POLICY IF EXISTS "Users can update own suggestions" ON ai_chat_app_schema.suggestions;
    DROP POLICY IF EXISTS "Users can delete own suggestions" ON ai_chat_app_schema.suggestions;
END $$;

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

-- Enable RLS for all tables with error handling
DO $$ 
BEGIN
    ALTER TABLE ai_chat_app_schema.documents ENABLE ROW LEVEL SECURITY;
EXCEPTION 
    WHEN others THEN null;
END $$;

DO $$ 
BEGIN
    ALTER TABLE ai_chat_app_schema.chats ENABLE ROW LEVEL SECURITY;
EXCEPTION 
    WHEN others THEN null;
END $$;

DO $$ 
BEGIN
    ALTER TABLE ai_chat_app_schema.messages ENABLE ROW LEVEL SECURITY;
EXCEPTION 
    WHEN others THEN null;
END $$;

DO $$ 
BEGIN
    ALTER TABLE ai_chat_app_schema.votes ENABLE ROW LEVEL SECURITY;
EXCEPTION 
    WHEN others THEN null;
END $$;

DO $$ 
BEGIN
    ALTER TABLE ai_chat_app_schema.suggestions ENABLE ROW LEVEL SECURITY;
EXCEPTION 
    WHEN others THEN null;
END $$;

-- Grant permissions with error handling
DO $$ 
BEGIN
    GRANT USAGE ON SCHEMA ai_chat_app_schema TO authenticated;
    GRANT ALL ON ALL TABLES IN SCHEMA ai_chat_app_schema TO authenticated;
    GRANT ALL ON ALL SEQUENCES IN SCHEMA ai_chat_app_schema TO authenticated;
EXCEPTION 
    WHEN others THEN null;
END $$;

DO $$ 
BEGIN
    GRANT USAGE ON SCHEMA ai_chat_app_schema TO anon;
    GRANT SELECT ON ALL TABLES IN SCHEMA ai_chat_app_schema TO anon;
EXCEPTION 
    WHEN others THEN null;
END $$;

-- Documents policies
CREATE POLICY "Users can view own documents" ON ai_chat_app_schema.documents
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create own documents" ON ai_chat_app_schema.documents
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own documents" ON ai_chat_app_schema.documents
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own documents" ON ai_chat_app_schema.documents
    FOR DELETE USING (auth.uid() = user_id);

-- Chats policies
CREATE POLICY "Users can view own chats" ON ai_chat_app_schema.chats
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create own chats" ON ai_chat_app_schema.chats
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own chats" ON ai_chat_app_schema.chats
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own chats" ON ai_chat_app_schema.chats
    FOR DELETE USING (auth.uid() = user_id);

-- Messages policies
CREATE POLICY "Users can view messages from their chats" ON ai_chat_app_schema.messages
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM ai_chat_app_schema.chats
            WHERE chats.id = messages.chat_id
            AND chats.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can create messages in their chats" ON ai_chat_app_schema.messages
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM ai_chat_app_schema.chats
            WHERE chats.id = messages.chat_id
            AND chats.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update messages in their chats" ON ai_chat_app_schema.messages
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM ai_chat_app_schema.chats
            WHERE chats.id = messages.chat_id
            AND chats.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete messages from their chats" ON ai_chat_app_schema.messages
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM ai_chat_app_schema.chats
            WHERE chats.id = messages.chat_id
            AND chats.user_id = auth.uid()
        )
    );

-- Votes policies
CREATE POLICY "Users can view votes from their chats" ON ai_chat_app_schema.votes
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM ai_chat_app_schema.chats
            WHERE chats.id = votes.chat_id
            AND chats.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can create votes in their chats" ON ai_chat_app_schema.votes
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM ai_chat_app_schema.chats
            WHERE chats.id = votes.chat_id
            AND chats.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update votes in their chats" ON ai_chat_app_schema.votes
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM ai_chat_app_schema.chats
            WHERE chats.id = votes.chat_id
            AND chats.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete votes from their chats" ON ai_chat_app_schema.votes
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM ai_chat_app_schema.chats
            WHERE chats.id = votes.chat_id
            AND chats.user_id = auth.uid()
        )
    );

-- Suggestions policies
CREATE POLICY "Users can view own suggestions" ON ai_chat_app_schema.suggestions
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create own suggestions" ON ai_chat_app_schema.suggestions
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own suggestions" ON ai_chat_app_schema.suggestions
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own suggestions" ON ai_chat_app_schema.suggestions
    FOR DELETE USING (auth.uid() = user_id); 