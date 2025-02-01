-- Create Votes table
CREATE TABLE IF NOT EXISTS ai_chat_app_schema.votes (
    chat_id UUID NOT NULL REFERENCES ai_chat_app_schema.chats(id) ON DELETE CASCADE,
    message_id UUID NOT NULL REFERENCES ai_chat_app_schema.messages(id) ON DELETE CASCADE,
    is_upvoted BOOLEAN NOT NULL,
    -- Set composite primary key
    PRIMARY KEY (chat_id, message_id)
);

-- Enable Row Level Security
DO $$ 
BEGIN
    ALTER TABLE ai_chat_app_schema.votes ENABLE ROW LEVEL SECURITY;
EXCEPTION 
    WHEN others THEN null; -- Ignore if RLS is already enabled
END $$;

-- Create RLS Policies for votes
DO $$ 
BEGIN
    -- Drop existing policies if they exist
    DROP POLICY IF EXISTS "Users can view votes on their chats" ON ai_chat_app_schema.votes;
    DROP POLICY IF EXISTS "Users can create votes on their chats" ON ai_chat_app_schema.votes;
    DROP POLICY IF EXISTS "Users can update votes on their chats" ON ai_chat_app_schema.votes;
    DROP POLICY IF EXISTS "Users can delete votes on their chats" ON ai_chat_app_schema.votes;
END $$;

CREATE POLICY "Users can view votes on their chats" ON ai_chat_app_schema.votes
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM ai_chat_app_schema.chats
            WHERE chats.id = votes.chat_id
            AND chats.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can create votes on their chats" ON ai_chat_app_schema.votes
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM ai_chat_app_schema.chats
            WHERE chats.id = votes.chat_id
            AND chats.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can update votes on their chats" ON ai_chat_app_schema.votes
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM ai_chat_app_schema.chats
            WHERE chats.id = votes.chat_id
            AND chats.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete votes on their chats" ON ai_chat_app_schema.votes
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM ai_chat_app_schema.chats
            WHERE chats.id = votes.chat_id
            AND chats.user_id = auth.uid()
        )
    );

-- Grant necessary permissions
DO $$
BEGIN
    GRANT ALL ON ai_chat_app_schema.votes TO authenticated;
    GRANT SELECT ON ai_chat_app_schema.votes TO anon;
EXCEPTION 
    WHEN others THEN null; -- Ignore if permissions are already granted
END $$;

