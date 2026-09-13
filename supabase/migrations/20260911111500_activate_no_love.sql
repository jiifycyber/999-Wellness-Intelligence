update public.music_tracks
set
  active = true,
  featured = true,
  audio_path = 'duke-da-boss-x/no-love/no-love.mp3',
  artwork_path = 'duke-da-boss-x/no-love/cover.jpg',
  updated_at = now()
where lower(artist_name) = lower('Duke Da Boss X')
  and lower(title) = lower('No Love');
