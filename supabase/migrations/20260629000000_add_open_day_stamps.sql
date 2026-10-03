CREATE TABLE IF NOT EXISTS open_day_stamps (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  location_id TEXT NOT NULL,
  scanned_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, location_id)
);

ALTER TABLE open_day_stamps ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own stamps"
  ON open_day_stamps FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own stamps"
  ON open_day_stamps FOR INSERT
  WITH CHECK (auth.uid() = user_id);
