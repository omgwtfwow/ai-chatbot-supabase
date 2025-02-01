-- Enable pg_trgm for text search
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Indexes for the users table
CREATE INDEX IF NOT EXISTS idx_users_email ON ai_chat_app_schema.users(email);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON ai_chat_app_schema.users(created_at);

-- Indexes for the chats table
CREATE INDEX IF NOT EXISTS idx_chats_user_id ON ai_chat_app_schema.chats(user_id);
CREATE INDEX IF NOT EXISTS idx_chats_created_at ON ai_chat_app_schema.chats(created_at);
CREATE INDEX IF NOT EXISTS idx_chats_updated_at ON ai_chat_app_schema.chats(updated_at);

-- Indexes for the messages table
CREATE INDEX IF NOT EXISTS idx_messages_chat_id ON ai_chat_app_schema.messages(chat_id);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON ai_chat_app_schema.messages(created_at);
CREATE INDEX IF NOT EXISTS idx_messages_role ON ai_chat_app_schema.messages(role);

-- Indexes for the documents table
CREATE INDEX IF NOT EXISTS idx_documents_user_id ON ai_chat_app_schema.documents(user_id);
CREATE INDEX IF NOT EXISTS idx_documents_created_at ON ai_chat_app_schema.documents(created_at);
CREATE INDEX IF NOT EXISTS idx_documents_title_gin ON ai_chat_app_schema.documents USING gin(title gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_documents_content_gin ON ai_chat_app_schema.documents USING gin(content gin_trgm_ops);

-- Indexes for the suggestions table
CREATE INDEX IF NOT EXISTS idx_suggestions_document_id ON ai_chat_app_schema.suggestions(document_id);
CREATE INDEX IF NOT EXISTS idx_suggestions_user_id ON ai_chat_app_schema.suggestions(user_id);
CREATE INDEX IF NOT EXISTS idx_suggestions_is_resolved ON ai_chat_app_schema.suggestions(is_resolved);
CREATE INDEX IF NOT EXISTS idx_suggestions_created_at ON ai_chat_app_schema.suggestions(created_at);

-- Indexes for the votes table
CREATE INDEX IF NOT EXISTS idx_votes_message_id ON ai_chat_app_schema.votes(message_id);
CREATE INDEX IF NOT EXISTS idx_votes_chat_id ON ai_chat_app_schema.votes(chat_id);
CREATE INDEX IF NOT EXISTS idx_votes_composite ON ai_chat_app_schema.votes(message_id, chat_id);

-- Add text search capabilities
-- ALTER TABLE ai_chat_app_schema.documents ADD COLUMN IF NOT EXISTS search_vector tsvector;
-- CREATE INDEX IF NOT EXISTS idx_documents_search_vector ON ai_chat_app_schema.documents USING gin(search_vector);

-- -- Create function to update search vector
-- CREATE OR REPLACE FUNCTION ai_chat_app_schema.documents_search_vector_trigger() RETURNS trigger AS $$
-- BEGIN
--     NEW.search_vector :=
--         setweight(to_tsvector('english', COALESCE(NEW.title, '')), 'A') ||
--         setweight(to_tsvector('english', COALESCE(NEW.content, '')), 'B');
--     RETURN NEW;
-- END;
-- $$ LANGUAGE plpgsql;

-- -- Create trigger for search vector updates
-- CREATE TRIGGER documents_search_vector_update
--     BEFORE INSERT OR UPDATE ON ai_chat_app_schema.documents
--     FOR EACH ROW
--     EXECUTE FUNCTION ai_chat_app_schema.documents_search_vector_trigger();

-- Add compression for large text fields
ALTER TABLE ai_chat_app_schema.documents ALTER COLUMN content SET STORAGE EXTENDED;
ALTER TABLE ai_chat_app_schema.messages ALTER COLUMN content SET STORAGE EXTENDED;

-- Add partial indexes for common queries
CREATE INDEX IF NOT EXISTS idx_suggestions_unresolved 
    ON ai_chat_app_schema.suggestions(created_at) 
    WHERE NOT is_resolved;
