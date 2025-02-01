import { Message } from 'ai';
import { toast } from 'sonner';
import { useSWRConfig } from 'swr';
import { useCopyToClipboard } from 'usehooks-ts';

import { Vote } from '@/lib/supabase/types';
import { getMessageIdFromAnnotations } from '@/lib/utils';

import { CopyIcon, ThumbDownIcon, ThumbUpIcon } from './icons';
import { Button } from '../ui/button';
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from '../ui/tooltip';

export function MessageActions({
  chatId,
  message,
  vote,
  isLoading,
}: {
  chatId: string;
  message: Message;
  vote: Vote | undefined;
  isLoading: boolean;
}) {
  const { mutate } = useSWRConfig();
  const [_, copyToClipboard] = useCopyToClipboard();

  const handleVote = async (type: 'up' | 'down') => {
    const messageId = getMessageIdFromAnnotations(message);

    const votePromise = fetch('/api/vote', {
      method: 'PATCH',
      body: JSON.stringify({
        chatId,
        messageId,
        type,
      }),
    });

    toast.promise(votePromise, {
      loading: `${type === 'up' ? 'Upvoting' : 'Downvoting'} Response...`,
      success: () => {
        mutate<Array<Vote>>(
          `/api/vote?chatId=${chatId}`,
          (currentVotes) => {
            if (!currentVotes) return [];
            const votesWithoutCurrent = currentVotes.filter(
              (vote) => vote.message_id !== message.id
            );
            return [
              ...votesWithoutCurrent,
              {
                chat_id: chatId,
                message_id: message.id,
                is_upvoted: type === 'up',
                updated_at: new Date().toISOString(),
              },
            ];
          },
          { revalidate: false }
        );
        return `${type === 'up' ? 'Upvoted' : 'Downvoted'} Response!`;
      },
      error: `Failed to ${type === 'up' ? 'upvote' : 'downvote'} response.`,
    });
  };

  if (isLoading) return null;
  if (message.role === 'user') return null;
  if (message.toolInvocations && message.toolInvocations.length > 0)
    return null;

  return (
    <TooltipProvider delayDuration={0}>
      <div className="flex flex-row gap-2">
        <Tooltip>
          <TooltipTrigger asChild>
            <Button
              className="py-1 px-2 h-fit text-muted-foreground"
              variant="outline"
              onClick={async () => {
                await copyToClipboard(message.content as string);
                toast.success('Copied to clipboard!');
              }}
            >
              <CopyIcon />
            </Button>
          </TooltipTrigger>
          <TooltipContent>Copy</TooltipContent>
        </Tooltip>

        <Tooltip>
          <TooltipTrigger asChild>
            <Button
              className="py-1 px-2 h-fit text-muted-foreground !pointer-events-auto"
              disabled={vote && vote.is_upvoted}
              variant="outline"
              onClick={() => handleVote('up')}
            >
              <ThumbUpIcon />
            </Button>
          </TooltipTrigger>
          <TooltipContent>Upvote Response</TooltipContent>
        </Tooltip>

        <Tooltip>
          <TooltipTrigger asChild>
            <Button
              className="py-1 px-2 h-fit text-muted-foreground !pointer-events-auto"
              variant="outline"
              disabled={vote && !vote.is_upvoted}
              onClick={() => handleVote('down')}
            >
              <ThumbDownIcon />
            </Button>
          </TooltipTrigger>
          <TooltipContent>Downvote Response</TooltipContent>
        </Tooltip>
      </div>
    </TooltipProvider>
  );
}
