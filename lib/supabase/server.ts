import { createServerClient } from '@supabase/ssr';
import { cookies } from 'next/headers';

export const createClient = async () => {
  const cookieStore = await cookies();

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        get(name: string) {
          return cookieStore.get(name)?.value;
        },
        set(name: string, value: string, options: { domain?: string }) {
          try {
            cookieStore.set({ name, value, ...options, domain: process.env.NEXT_PUBLIC_COOKIE_DOMAIN });
          } catch (error) {
            // The `set` method was called from a Server Component.
            // This can be ignored if you have middleware refreshing
            // user sessions.
          }
        },
        remove(name: string, options: { domain?: string }) {
          try {
            cookieStore.set({ name, value: '', ...options, domain: process.env.NEXT_PUBLIC_COOKIE_DOMAIN });
          } catch (error) {
            // The `remove` method was called from a Server Component.
            // This can be ignored if you have middleware refreshing
            // user sessions.
          }
        },
      },
      db: {
        schema: 'ai_chat_app_schema'
      }
    }
  );
};
