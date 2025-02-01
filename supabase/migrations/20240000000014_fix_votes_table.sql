-- Add updated_at column if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'ai_chat_app_schema'
        AND table_name = 'votes'
        AND column_name = 'updated_at'
    ) THEN
        ALTER TABLE ai_chat_app_schema.votes
        ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW());
    END IF;
END $$;

-- Add trigger to automatically update updated_at
CREATE OR REPLACE FUNCTION ai_chat_app_schema.update_votes_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = TIMEZONE('utc', NOW());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_votes_updated_at ON ai_chat_app_schema.votes;
CREATE TRIGGER update_votes_updated_at
    BEFORE UPDATE ON ai_chat_app_schema.votes
    FOR EACH ROW
    EXECUTE FUNCTION ai_chat_app_schema.update_votes_updated_at(); 