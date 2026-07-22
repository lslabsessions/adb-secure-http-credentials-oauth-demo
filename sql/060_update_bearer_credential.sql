-- Updates the stored Bearer token and repeats the request.

SET SERVEROUTPUT ON

BEGIN
    DBMS_CLOUD.UPDATE_CREDENTIAL(
        credential_name => 'HTTPBIN_BEARER_HTTP_CRED',
        attribute       => 'PASSWORD',
        value           => 'def456'
    );
END;
/

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
