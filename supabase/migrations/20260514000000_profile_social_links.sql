-- Add social media link handles to profiles so users can showcase their socials
alter table public.profiles
    add column if not exists instagram_handle text,
    add column if not exists twitter_handle text,
    add column if not exists facebook_handle text,
    add column if not exists tiktok_handle text;
