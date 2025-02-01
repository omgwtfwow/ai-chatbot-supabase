-- Drop existing policies if they exist
DO $$ 
BEGIN
    -- Drop policies only if tables exist
    IF EXISTS (
        SELECT FROM pg_tables 
        WHERE schemaname = 'ai_chat_app_schema' 
        AND tablename = 'chats'
    ) THEN
        -- Drop chat policies if they exist
        DROP POLICY IF EXISTS "Users can view own chats" ON ai_chat_app_schema.chats;
        DROP POLICY IF EXISTS "Users can create own chats" ON ai_chat_app_schema.chats;
        DROP POLICY IF EXISTS "Users can update own chats" ON ai_chat_app_schema.chats;
        DROP POLICY IF EXISTS "Users can delete own chats" ON ai_chat_app_schema.chats;
    END IF;

    IF EXISTS (
        SELECT FROM pg_tables 
        WHERE schemaname = 'ai_chat_app_schema' 
        AND tablename = 'messages'
    ) THEN
        -- Drop message policies if they exist
        DROP POLICY IF EXISTS "Users can view messages from their chats" ON ai_chat_app_schema.messages;
        DROP POLICY IF EXISTS "Users can create messages in their chats" ON ai_chat_app_schema.messages;
        DROP POLICY IF EXISTS "Users can update messages in their chats" ON ai_chat_app_schema.messages;
        DROP POLICY IF EXISTS "Users can delete messages from their chats" ON ai_chat_app_schema.messages;
    END IF;
END $$;

-- Create Chats table
CREATE TABLE IF NOT EXISTS ai_chat_app_schema.chats (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT,
    user_id UUID NOT NULL REFERENCES ai_chat_app_schema.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL
);

-- Enable RLS
DO $$ 
BEGIN
    -- Enable RLS on chats table
    ALTER TABLE ai_chat_app_schema.chats ENABLE ROW LEVEL SECURITY;
EXCEPTION 
    WHEN others THEN null; -- Ignore if RLS is already enabled
END $$;

-- Create RLS Policies for chats
CREATE POLICY "Users can view own chats" ON ai_chat_app_schema.chats
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create own chats" ON ai_chat_app_schema.chats
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own chats" ON ai_chat_app_schema.chats
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own chats" ON ai_chat_app_schema.chats
    FOR DELETE USING (auth.uid() = user_id);

-- Grant necessary permissions
GRANT ALL ON ai_chat_app_schema.chats TO authenticated;
GRANT SELECT ON ai_chat_app_schema.chats TO anon;

-- Create Messages table
CREATE TABLE IF NOT EXISTS ai_chat_app_schema.messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    chat_id UUID NOT NULL REFERENCES ai_chat_app_schema.chats(id) ON DELETE CASCADE,
    role TEXT NOT NULL,
    content JSONB NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL
);

-- Enable RLS
DO $$ 
BEGIN
    -- Enable RLS on messages table
    ALTER TABLE ai_chat_app_schema.messages ENABLE ROW LEVEL SECURITY;
EXCEPTION 
    WHEN others THEN null; -- Ignore if RLS is already enabled
END $$;

-- Create RLS Policies for messages
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

-- Grant necessary permissions
DO $$
BEGIN
    GRANT ALL ON ai_chat_app_schema.messages TO authenticated;
    GRANT SELECT ON ai_chat_app_schema.messages TO anon;
EXCEPTION 
    WHEN others THEN null; -- Ignore if permissions are already granted
END $$;
