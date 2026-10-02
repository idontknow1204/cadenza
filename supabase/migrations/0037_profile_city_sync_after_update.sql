-- New auth users always start with the empty home_cities default. Sync only
-- after onboarding/profile edits supply cities; this also keeps auth signup
-- independent from opportunity preference maintenance.

DROP TRIGGER IF EXISTS profiles_home_cities_sync_trg ON profiles;
CREATE TRIGGER profiles_home_cities_sync_trg
  AFTER UPDATE OF home_cities ON profiles
  FOR EACH ROW
  WHEN (OLD.home_cities IS DISTINCT FROM NEW.home_cities)
  EXECUTE FUNCTION sync_user_base_cities_from_profile();
