import { revalidatePath } from 'next/cache';
import { createClient } from '@/lib/supabase/server';
import {
  handleDatabaseError,
  PostgrestError,
  type Client,
  type Message,
  type Database,
} from '@/lib/supabase/types';

type Tables = Database['ai_chat_app_schema']['Tables'];
type MessageInsert = Tables['messages']['Insert'];
type VoteInsert = Tables['votes']['Insert'];
type DocumentInsert = Tables['documents']['Insert'];
type SuggestionInsert = Tables['suggestions']['Insert'];

const getSupabase = async () => createClient();

async function mutateQuery<T extends any[]>(
  queryFn: (client: Client, ...args: T) => Promise<void>,
  args: T,
  tags: string[]
) {
  const supabase = await getSupabase();
  try {
    await queryFn(supabase, ...args);
    tags.forEach((tag) => revalidatePath(tag));
  } catch (error) {
    handleDatabaseError(error as PostgrestError);
  }
}

export async function saveChat({
  id,
  userId,
  title,
}: {
  id: string;
  userId: string;
  title: string;
}) {
  await mutateQuery(
    async (client, { id, userId, title }) => {
      const now = new Date().toISOString();
      const { error } = await client.from('chats').insert({
        id,
        user_id: userId,
        title,
        created_at: now,
        updated_at: now,
      });
      if (error) throw error;
    },
    [{ id, userId, title }],
    [`user_${userId}_chats`, `chat_${id}`, 'chats']
  );
}

export async function deleteChatById(chatId: string, userId: string) {
  await mutateQuery(
    async (client, id) => {
      // Messages will be automatically deleted due to CASCADE
      const { error } = await client
        .from('chats')
        .delete()
        .eq('id', id);
      if (error) throw error;
    },
    [chatId],
    [
      `chat_${chatId}`,
      `user_${userId}_chats`,
      `chat_${chatId}_messages`,
      `chat_${chatId}_votes`,
      'chats',
    ]
  );
}

export async function saveMessages(
  messages: Array<Message>,
  chatId: string
) {
  await mutateQuery(
    async (client) => {
      const { error } = await client
        .from('messages')
        .insert(messages.map(message => ({
          id: message.id,
          chat_id: chatId,
          role: message.role,
          content: message.content,
          created_at: message.created_at,
        } as MessageInsert)));
      if (error) throw error;
    },
    [],
    [`chat_${chatId}_messages`]
  );
}

export async function saveVote(vote: VoteInsert, chatId: string) {
  await mutateQuery(
    async (client) => {
      const { error: updateError } = await client
        .from('votes')
        .upsert(
          {
            ...vote,
            chat_id: chatId,
          },
          {
            onConflict: 'chat_id',
          }
        );
      if (updateError) throw updateError;
    },
    [],
    [`chat_${chatId}_votes`]
  );
}

export async function saveDocument({
  id,
  userId,
  title,
  content,
}: {
  id: string;
  userId: string;
  title: string;
  content: string;
}) {
  await mutateQuery(
    async (client) => {
      const { error } = await client.from('documents').insert({
        id,
        user_id: userId,
        title,
        content,
      } as DocumentInsert);
      if (error) throw error;
    },
    [],
    [`document_${id}`]
  );
}

export async function saveSuggestion({
  id,
  documentId,
  originalText,
  suggestedText,
  documentCreatedAt,
  userId,
}: {
  id: string;
  documentId: string;
  originalText: string;
  suggestedText: string;
  documentCreatedAt: string;
  userId: string;
}) {
  await mutateQuery(
    async (client) => {
      const { error } = await client
        .from('suggestions')
        .insert({
          id,
          document_id: documentId,
          document_created_at: documentCreatedAt,
          original_text: originalText,
          suggested_text: suggestedText,
          user_id: userId,
        } as SuggestionInsert);
      if (error) throw error;
    },
    [],
    [`document_${documentId}_suggestions`]
  );
}
