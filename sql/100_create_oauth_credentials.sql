-- Public Duende demo client credentials.
-- Run as the application schema where the function GET_BEARER_CREDENTIAL is created.

BEGIN
    DBMS_CLOUD.CREATE_CREDENTIAL(
        credential_name => 'API_OAUTH_CLIENT_CRED',
        username        => 'm2m',
        password        => 'secret'
    );
END;
/

-- The OAuth access token will be stored in the password field of this credential.
-- The initial value is replaced before the protected endpoint is called.
BEGIN
    DBMS_CLOUD.CREATE_CREDENTIAL(
        credential_name => 'DEMO_BEARER_CRED',
        username        => 'BEARER_TOKEN',
        password        => 'NOT_INITIALIZED'
    );
END;
/
