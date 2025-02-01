-- Drop existing constraint if it exists
ALTER TABLE ai_chat_app_schema.votes 
DROP CONSTRAINT IF EXISTS votes_message_id_key;

-- Add unique constraint for message_id
ALTER TABLE ai_chat_app_schema.votes
ADD CONSTRAINT votes_message_id_key UNIQUE (message_id);

-- Add index for performance
CREATE INDEX IF NOT EXISTS idx_votes_message_id 
ON ai_chat_app_schema.votes(message_id);

-- Add index for chat_id lookups
CREATE INDEX IF NOT EXISTS idx_votes_chat_id 
ON ai_chat_app_schema.votes(chat_id); 