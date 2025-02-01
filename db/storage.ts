import type { SupabaseClient } from '@supabase/supabase-js';
import type { Database } from '@/lib/supabase/types';

export const BUCKET_NAME = 'ai_chat_app_storage';

async function ensureBucketExists(client: SupabaseClient<Database>) {
  const { data: buckets } = await client.storage.listBuckets();
  const bucketExists = buckets?.some((bucket) => bucket.name === BUCKET_NAME);

  if (!bucketExists) {
    const { error } = await client.storage.createBucket(BUCKET_NAME, {
      public: false, // Make bucket private
      fileSizeLimit: 52428800, // 50MB in bytes
      allowedMimeTypes: ['image/*', 'application/pdf', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'],
    });

    if (error) {
      throw error;
    }
  }
}

type UploadParams = {
  file: File;
  path: string[];
};

export async function upload(
  client: SupabaseClient<Database>,
  { file, path }: UploadParams
) {
  await ensureBucketExists(client);

  const storage = client.storage.from(BUCKET_NAME);

  const result = await storage.upload(path.join('/'), file, {
    upsert: true,
    cacheControl: '3600',
  });

  if (!result.error) {
    // Create a signed URL that expires in 1 hour
    const { data, error } = await storage.createSignedUrl(
      path.join('/'),
      3600 // 1 hour in seconds
    );

    if (error || !data?.signedUrl) {
      throw new Error('Failed to create signed URL');
    }

    return data.signedUrl;
  }

  throw result.error;
}

type RemoveParams = {
  path: string[];
};

export async function remove(client: SupabaseClient<Database>, { path }: RemoveParams) {
  return client.storage
    .from(BUCKET_NAME)
    .remove([decodeURIComponent(path.join('/'))]);
}

type DownloadParams = {
  path: string;
};

export async function download(
  client: SupabaseClient<Database>,
  { path }: DownloadParams
) {
  return client.storage.from(BUCKET_NAME).download(path);
}

type ShareParams = {
  path: string;
  expireIn: number;
  options?: {
    download?: boolean;
  };
};

export async function share(
  client: SupabaseClient<Database>,
  { path, expireIn, options }: ShareParams
) {
  return client.storage
    .from(BUCKET_NAME)
    .createSignedUrl(path, expireIn, options);
}
