import { getSession } from '@/db/cached-queries';
import { saveVote } from '@/db/mutations';
import { createClient } from '@/lib/supabase/server';
import type { VoteInsert } from '@/lib/supabase/types';

export async function POST(request: Request) {
  try {
    const { chatId, messageId, type } = await request.json();

    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();

    if (!user) {
      return new Response('Unauthorized', { status: 401 });
    }

    await saveVote({
      chat_id: chatId,
      message_id: messageId,
      is_upvoted: type === 'up'
    } as VoteInsert, chatId);

    return new Response('Vote recorded', { status: 200 });
  } catch (error) {
    console.error('Error recording vote:', error);
    return new Response('An error occurred', { status: 500 });
  }
}

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const chatId = searchParams.get('chatId');

  if (!chatId) {
    return new Response('Missing chatId', { status: 400 });
  }

  try {
    const supabase = await createClient();
    const { data: votes } = await supabase
      .from('votes')
      .select()
      .eq('chat_id', chatId);

    return Response.json(votes || [], { status: 200 });
  } catch (error) {
    console.error('Error fetching votes:', error);
    return new Response('An error occurred', { status: 500 });
  }
}

export async function PATCH(request: Request) {
  try {
    const {
      chatId,
      messageId,
      type,
    }: { chatId: string; messageId: string; type: 'up' | 'down' } =
      await request.json();

    if (!chatId || !messageId || !type) {
      return new Response('messageId and type are required', { status: 400 });
    }

    const user = await getSession();

    if (!user || !user.email) {
      return new Response('Unauthorized', { status: 401 });
    }

    await saveVote({
      chat_id: chatId,
      message_id: messageId,
      is_upvoted: type === 'up'
    } as VoteInsert, chatId);

    return new Response('Message voted', { status: 200 });
  } catch (error) {
    console.error('Error voting message:', error);

    // Handle specific error cases
    if (error instanceof Error && error.message === 'Message not found') {
      return new Response('Message not found', { status: 404 });
    }

    return new Response('An error occurred while voting', { status: 500 });
  }
}
