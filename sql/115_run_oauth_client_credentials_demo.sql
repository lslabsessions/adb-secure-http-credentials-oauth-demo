-- Run this script twice.
-- First run: obtains and stores a new token.
-- Second run before expiry: reuses the stored bearer credential.

SET SERVEROUTPUT ON

DECLARE
    l_credential_name VARCHAR2(128);
    l_response        DBMS_CLOUD_TYPES.resp;
    l_response_body   CLOB;
    l_status_code     PLS_INTEGER;
    l_headers         CLOB := '{"Accept":"application/json"}';
BEGIN
    l_credential_name := get_bearer_credential(
        p_cache_key          => 'BEARER_API',
        p_token_url          => 'https://demo.duendesoftware.com/connect/token',
        p_client_credential  => 'API_OAUTH_CLIENT_CRED',
        p_bearer_credential  => 'DEMO_BEARER_CRED',
        p_scope              => 'api',
        p_refresh_margin_seconds => 60
    );

    l_response := DBMS_CLOUD.SEND_REQUEST(
        credential_name => l_credential_name,
        uri             => 'bearer://demo.duendesoftware.com/api/test',
        method          => DBMS_CLOUD.METHOD_GET,
        headers         => l_headers
    );

    l_status_code := DBMS_CLOUD.GET_RESPONSE_STATUS_CODE(l_response);
    l_response_body := DBMS_CLOUD.GET_RESPONSE_TEXT(l_response);

    DBMS_OUTPUT.PUT_LINE('Protected API HTTP Status: ' || l_status_code);
    DBMS_OUTPUT.PUT_LINE(DBMS_LOB.SUBSTR(l_response_body, 32767, 1));


EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('Backtrace: ' || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
        RAISE;
END;
/
