SELECT token_key,
       obtained_at,
       expires_at,
       CASE
           WHEN expires_at IS NULL THEN 'NOT INITIALIZED'
           WHEN SYSTIMESTAMP < expires_at THEN 'VALID'
           ELSE 'EXPIRED'
       END AS token_status
  FROM oauth_token_cache;