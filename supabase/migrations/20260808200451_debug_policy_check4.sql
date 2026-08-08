-- Isolationstest: kann irgendeine zusätzliche permissive UPDATE-Policy
-- (mit trivialem USING true) einem Nicht-Eigentümer das Ändern einer
-- fremden Zeile erlauben? Rein diagnostisch, wird gleich wieder entfernt.
CREATE POLICY "debug_locations_update_always_true" ON "public"."locations"
  FOR UPDATE
  USING (true)
  WITH CHECK (true);
