-- The table stores token timing metadata only. It does not store the token.

CREATE TABLE oauth_token_cache (
    token_key    VARCHAR2(128)
                 CONSTRAINT oauth_token_cache_pk PRIMARY KEY,
    obtained_at  TIMESTAMP WITH TIME ZONE,
    expires_at   TIMESTAMP WITH TIME ZONE
);

INSERT INTO oauth_token_cache (
    token_key,
    obtained_at,
    expires_at
)
VALUES (
    'BEARER_API',
    NULL,
    NULL
);

COMMIT;