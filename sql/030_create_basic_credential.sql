-- Run as the application schema.
-- The credentials belong to a public test service.

BEGIN
    DBMS_CLOUD.CREATE_CREDENTIAL(
        credential_name => 'POSTMAN_BASIC_HTTP_CRED',
        username        => 'postman',
        password        => 'password'
    );
END;
/
