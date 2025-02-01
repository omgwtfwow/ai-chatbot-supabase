-- Add policy for suggestions table as well
ALTER TABLE ai_chat_app_schema.suggestions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own suggestions" ON ai_chat_app_schema.suggestions;
DROP POLICY IF EXISTS "Users can create own suggestions" ON ai_chat_app_schema.suggestions;

CREATE POLICY "Users can view own suggestions" ON ai_chat_app_schema.suggestions
    FOR SELECT USING (
        auth.uid() = user_id
    );

CREATE POLICY "Users can create own suggestions" ON ai_chat_app_schema.suggestions
    FOR INSERT WITH CHECK (
        auth.uid() = user_id
    ); 