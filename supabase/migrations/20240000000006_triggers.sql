-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION ai_chat_app_schema.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = TIMEZONE('utc', NOW());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add triggers for updated_at
CREATE TRIGGER handle_users_updated_at
    BEFORE UPDATE ON ai_chat_app_schema.users
    FOR EACH ROW
    EXECUTE FUNCTION ai_chat_app_schema.handle_updated_at();

CREATE TRIGGER handle_chats_updated_at
    BEFORE UPDATE ON ai_chat_app_schema.chats
    FOR EACH ROW
    EXECUTE FUNCTION ai_chat_app_schema.handle_updated_at();

CREATE TRIGGER handle_votes_updated_at
    BEFORE UPDATE ON ai_chat_app_schema.votes
    FOR EACH ROW
    EXECUTE FUNCTION ai_chat_app_schema.handle_updated_at(); 