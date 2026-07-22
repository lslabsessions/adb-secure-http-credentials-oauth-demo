-- Returns the name of a bearer credential that contains a valid access token.
-- The function never returns or prints the access token.
--
-- Flow:
-- 1. Lock the cache row.
-- 2. Reuse the stored bearer credential while the token is valid.
-- 3. If the token is not valid, obtain a token with OAuth Client Credentials.
-- 4. Store the new token in the password field of the bearer credential.
-- 5. Store obtained_at and expires_at in the cache table.

SET DEFINE OFF

CREATE OR REPLACE FUNCTION get_bearer_credential (
    p_cache_key                IN VARCHAR2,
    p_token_url                IN VARCHAR2,
    p_client_credential        IN VARCHAR2,
    p_bearer_credential        IN VARCHAR2,
    p_scope                    IN VARCHAR2 DEFAULT NULL,
    p_default_expires_seconds  IN PLS_INTEGER DEFAULT 3600,
    p_refresh_margin_seconds   IN PLS_INTEGER DEFAULT 60
) RETURN VARCHAR2
AUTHID DEFINER
IS
    PRAGMA AUTONOMOUS_TRANSACTION;

    l_request          UTL_HTTP.req;
    l_response         UTL_HTTP.resp;
    l_response_open    BOOLEAN := FALSE;

    l_request_body     VARCHAR2(32767);
    l_request_raw      RAW(32767);

    l_response_body    CLOB;
    l_buffer           VARCHAR2(32767);
    l_status_code      PLS_INTEGER;

    l_json             JSON_OBJECT_T;
    l_access_token     VARCHAR2(32767);
    l_expires_seconds  NUMBER;
    l_expires_at       TIMESTAMP WITH TIME ZONE;
    l_now              TIMESTAMP WITH TIME ZONE;
BEGIN
    SELECT expires_at
      INTO l_expires_at
      FROM oauth_token_cache
     WHERE token_key = p_cache_key
       FOR UPDATE;

    IF l_expires_at IS NOT NULL
       AND SYSTIMESTAMP <
           l_expires_at
           - NUMTODSINTERVAL(p_refresh_margin_seconds, 'SECOND')
    THEN
        DBMS_OUTPUT.PUT_LINE(
            'Reusing stored bearer credential. Token valid until: '
            || TO_CHAR(l_expires_at, 'YYYY-MM-DD HH24:MI:SS TZH:TZM')
        );

        COMMIT;
        RETURN p_bearer_credential;
    END IF;

    DBMS_OUTPUT.PUT_LINE('No valid cached token. Requesting a new access token.');

    l_request_body := 'grant_type=client_credentials';

    IF p_scope IS NOT NULL THEN
        l_request_body :=
            l_request_body
            || '&scope='
            || UTL_URL.ESCAPE(
                   url                   => p_scope,
                   escape_reserved_chars => TRUE,
                   url_charset            => 'AL32UTF8'
               );
    END IF;

    l_request_raw := UTL_I18N.STRING_TO_RAW(
        data        => l_request_body,
        dst_charset => 'AL32UTF8'
    );

    UTL_HTTP.SET_DETAILED_EXCP_SUPPORT(TRUE);
    UTL_HTTP.SET_RESPONSE_ERROR_CHECK(FALSE);
    UTL_HTTP.SET_TRANSFER_TIMEOUT(60);

    l_request := UTL_HTTP.BEGIN_REQUEST(
        url          => p_token_url,
        method       => 'POST',
        http_version => UTL_HTTP.HTTP_VERSION_1_1
    );

    -- Creates Authorization: Basic base64(client_id:client_secret)
    -- from the stored database credential.
    UTL_HTTP.SET_CREDENTIAL(
        r          => l_request,
        credential => p_client_credential,
        scheme     => 'BASIC'
    );

    UTL_HTTP.SET_HEADER(
        r     => l_request,
        name  => 'Content-Type',
        value => 'application/x-www-form-urlencoded'
    );

    UTL_HTTP.SET_HEADER(
        r     => l_request,
        name  => 'Accept',
        value => 'application/json'
    );

    UTL_HTTP.SET_HEADER(
        r     => l_request,
        name  => 'Content-Length',
        value => TO_CHAR(UTL_RAW.LENGTH(l_request_raw))
    );

    UTL_HTTP.WRITE_RAW(
        r    => l_request,
        data => l_request_raw
    );

    l_response := UTL_HTTP.GET_RESPONSE(l_request);
    l_response_open := TRUE;
    l_status_code := l_response.status_code;

    DBMS_LOB.CREATETEMPORARY(
        lob_loc => l_response_body,
        cache   => TRUE
    );

    BEGIN
        LOOP
            UTL_HTTP.READ_TEXT(
                r    => l_response,
                data => l_buffer,
                len  => 32767
            );

            DBMS_LOB.WRITEAPPEND(
                lob_loc => l_response_body,
                amount  => LENGTH(l_buffer),
                buffer  => l_buffer
            );
        END LOOP;
    EXCEPTION
        WHEN UTL_HTTP.END_OF_BODY THEN
            NULL;
    END;

    UTL_HTTP.END_RESPONSE(l_response);
    l_response_open := FALSE;

    IF l_status_code < 200 OR l_status_code >= 300 THEN
        RAISE_APPLICATION_ERROR(
            -20001,
            'Token endpoint returned HTTP '
            || l_status_code
            || ': '
            || DBMS_LOB.SUBSTR(l_response_body, 1500, 1)
        );
    END IF;

    l_json := JSON_OBJECT_T.PARSE(l_response_body);

    IF NOT l_json.HAS('access_token') THEN
        RAISE_APPLICATION_ERROR(
            -20002,
            'OAuth response does not contain access_token.'
        );
    END IF;

    l_access_token := l_json.GET_STRING('access_token');

    IF l_json.HAS('expires_in') THEN
        l_expires_seconds := l_json.GET_NUMBER('expires_in');
    ELSE
        l_expires_seconds := p_default_expires_seconds;
    END IF;

    IF l_expires_seconds IS NULL OR l_expires_seconds <= 0 THEN
        l_expires_seconds := p_default_expires_seconds;
    END IF;

    DBMS_CLOUD.UPDATE_CREDENTIAL(
        credential_name => p_bearer_credential,
        attribute       => 'PASSWORD',
        value           => l_access_token
    );

    l_now := SYSTIMESTAMP;
    l_expires_at :=
        l_now + NUMTODSINTERVAL(l_expires_seconds, 'SECOND');

    UPDATE oauth_token_cache
       SET obtained_at = l_now,
           expires_at  = l_expires_at
     WHERE token_key = p_cache_key;

    DBMS_OUTPUT.PUT_LINE(
        'Bearer credential updated. Token expires at: '
        || TO_CHAR(l_expires_at, 'YYYY-MM-DD HH24:MI:SS TZH:TZM')
    );

    IF l_response_body IS NOT NULL
       AND DBMS_LOB.ISTEMPORARY(l_response_body) = 1
    THEN
        DBMS_LOB.FREETEMPORARY(l_response_body);
    END IF;

    COMMIT;
    RETURN p_bearer_credential;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(
            -20003,
            'No OAuth token cache row exists for key: ' || p_cache_key
        );
    WHEN OTHERS THEN
        IF l_response_open THEN
            BEGIN
                UTL_HTTP.END_RESPONSE(l_response);
            EXCEPTION
                WHEN OTHERS THEN NULL;
            END;
        END IF;

        IF l_response_body IS NOT NULL
           AND DBMS_LOB.ISTEMPORARY(l_response_body) = 1
        THEN
            DBMS_LOB.FREETEMPORARY(l_response_body);
        END IF;

        ROLLBACK;
        RAISE;
END;
/
