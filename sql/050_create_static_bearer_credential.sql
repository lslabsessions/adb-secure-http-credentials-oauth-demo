-- Run as the application schema.
-- The token is a non-sensitive public test value.

BEGIN
    DBMS_CLOUD.CREATE_CREDENTIAL(
        credential_name => 'HTTPBIN_BEARER_HTTP_CRED',
        username        => 'BEARER_TOKEN',
        password        => 'abc123'
    );
END;
/
