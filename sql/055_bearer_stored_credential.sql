-- Uses the credential password as the Bearer token.
-- Expected result: HTTP 200 and a response containing token abc123.

SET SERVEROUTPUT ON

DECLARE
    l_response DBMS_CLOUD_TYPES.resp;
    l_body     CLOB;
BEGIN
    l_response := DBMS_CLOUD.SEND_REQUEST(
        credential_name => 'HTTPBIN_BEARER_HTTP_CRED',
        uri             => 'bearer://httpbin.org/bearer',
        method          => DBMS_CLOUD.METHOD_GET,
        headers         => '{"Accept":"application/json"}'
    );

    DBMS_OUTPUT.PUT_LINE(
        'HTTP Status: ' || DBMS_CLOUD.GET_RESPONSE_STATUS_CODE(l_response)
    );

    l_body := DBMS_CLOUD.GET_RESPONSE_TEXT(l_response);

    DBMS_OUTPUT.PUT_LINE(DBMS_LOB.SUBSTR(l_body, 32767, 1));
END;
/
