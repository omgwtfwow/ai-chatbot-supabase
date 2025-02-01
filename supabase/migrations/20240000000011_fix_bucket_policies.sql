-- First ensure buckets table has RLS enabled
ALTER TABLE storage.buckets ENABLE ROW LEVEL SECURITY;

-- Drop any existing bucket policies to start fresh
DO $$
BEGIN
    DROP POLICY IF EXISTS "Give users access to own folder 1" ON storage.buckets;
    DROP POLICY IF EXISTS "Allow bucket management" ON storage.buckets;
    DROP POLICY IF EXISTS "Allow public buckets" ON storage.buckets;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- Create a permissive bucket policy for authenticated users
CREATE POLICY "Allow bucket access"
ON storage.buckets
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- Create or update the storage bucket with unique name
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'ai_chat_app_storage',
    'ai_chat_app_storage',
    true,
    52428800, -- 50MB
    ARRAY['image/*', 'application/pdf']::text[]
)
ON CONFLICT (id) DO UPDATE
SET 
    public = true,
    file_size_limit = 52428800,
    allowed_mime_types = ARRAY['image/*', 'application/pdf']::text[];

-- Drop any existing object policies for this bucket
DO $$
BEGIN
    DROP POLICY IF EXISTS "Allow authenticated uploads" ON storage.objects;
    DROP POLICY IF EXISTS "Allow public downloads" ON storage.objects;
    DROP POLICY IF EXISTS "Allow authenticated updates" ON storage.objects;
    DROP POLICY IF EXISTS "Allow authenticated deletes" ON storage.objects;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- Create bucket-specific policies
CREATE POLICY "Allow authenticated uploads to ai_chat_app"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
    bucket_id = 'ai_chat_app_storage'
);

CREATE POLICY "Allow authenticated updates to ai_chat_app"
ON storage.objects FOR UPDATE TO authenticated
USING (
    bucket_id = 'ai_chat_app_storage'
    AND (auth.uid() = (storage.foldername(name))[1]::uuid)
);

CREATE POLICY "Allow authenticated deletes from ai_chat_app"
ON storage.objects FOR DELETE TO authenticated
USING (
    bucket_id = 'ai_chat_app_storage'
    AND (auth.uid() = (storage.foldername(name))[1]::uuid)
);

CREATE POLICY "Allow public downloads from ai_chat_app"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'ai_chat_app_storage');

-- Ensure proper permissions are granted
GRANT ALL ON storage.objects TO authenticated;
GRANT ALL ON storage.buckets TO authenticated;
GRANT SELECT ON storage.objects TO public;
GRANT SELECT ON storage.buckets TO public; 