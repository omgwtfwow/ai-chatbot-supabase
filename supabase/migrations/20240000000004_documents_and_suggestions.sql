-- Create Documents table
CREATE TABLE IF NOT EXISTS ai_chat_app_schema.documents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    content TEXT,
    user_id UUID NOT NULL REFERENCES ai_chat_app_schema.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
    -- Add unique constraint for the composite key
    UNIQUE (id, created_at)
);

-- Create Suggestions table
CREATE TABLE IF NOT EXISTS ai_chat_app_schema.suggestions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4() NOT NULL,
    document_id UUID NOT NULL,
    document_created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    original_text TEXT NOT NULL,
    suggested_text TEXT NOT NULL,
    description TEXT,
    is_resolved BOOLEAN NOT NULL DEFAULT false,
    user_id UUID NOT NULL REFERENCES ai_chat_app_schema.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()) NOT NULL,
    FOREIGN KEY (document_id, document_created_at) 
        REFERENCES ai_chat_app_schema.documents(id, created_at) ON DELETE CASCADE
);

-- Enable RLS
ALTER TABLE ai_chat_app_schema.documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_chat_app_schema.suggestions ENABLE ROW LEVEL SECURITY;