-- Enable RLS for documents table
ALTER TABLE ai_chat_app_schema.documents ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for documents
CREATE POLICY "Users can view own documents" ON ai_chat_app_schema.documents
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create own documents" ON ai_chat_app_schema.documents
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own documents" ON ai_chat_app_schema.documents
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own documents" ON ai_chat_app_schema.documents
    FOR DELETE USING (auth.uid() = user_id); 