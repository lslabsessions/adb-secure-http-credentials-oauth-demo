-- Expected result: HTTP 401 Unauthorized.

SET SERVEROUTPUT ON

DECLARE
    l_request       UTL_HTTP.req;
    l_response      UTL_HTTP.resp;
    l_response_open BOOLEAN := FALSE;
    l_buffer        VARCHAR2(32767);
BEGIN
    UTL_HTTP.SET_DETAILED_EXCP_SUPPORT(TRUE);
    UTL_HTTP.SET_RESPONSE_ERROR_CHECK(FALSE);

    l_request := UTL_HTTP.BEGIN_REQUEST(
        url          => 'https://postman-echo.com/basic-auth',
        method       => 'GET',
        http_version => UTL_HTTP.HTTP_VERSION_1_1
    );

    UTL_HTTP.SET_HEADER(
        r     => l_request,
        name  => 'Accept',
        value => 'application/json'
    );

    l_response := UTL_HTTP.GET_RESPONSE(l_request);
    l_response_open := TRUE;

    DBMS_OUTPUT.PUT_LINE(
        'HTTP Status: ' || l_response.status_code || ' ' || l_response.reason_phrase
    );

    BEGIN
        LOOP
            UTL_HTTP.READ_TEXT(l_response, l_buffer, 32767);
            DBMS_OUTPUT.PUT_LINE(l_buffer);
        END LOOP;
    EXCEPTION
        WHEN UTL_HTTP.END_OF_BODY THEN
            NULL;
    END;

    UTL_HTTP.END_RESPONSE(l_response);
    l_response_open := FALSE;
EXCEPTION
    WHEN OTHERS THEN
        IF l_response_open THEN
            BEGIN
                UTL_HTTP.END_RESPONSE(l_response);
            EXCEPTION
                WHEN OTHERS THEN NULL;
            END;
        END IF;

        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('UTL_HTTP detail: ' || UTL_HTTP.GET_DETAILED_SQLERRM);
        RAISE;
END;
/
