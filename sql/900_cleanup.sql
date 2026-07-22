-- Run as the application schema.

SET SERVEROUTPUT ON

DECLARE
    PROCEDURE drop_credential_if_exists(p_name IN VARCHAR2) IS
        l_count PLS_INTEGER;
    BEGIN
        SELECT COUNT(*)
          INTO l_count
          FROM user_credentials
         WHERE credential_name = UPPER(p_name);

        IF l_count > 0 THEN
            DBMS_CLOUD.DROP_CREDENTIAL(p_name);
            DBMS_OUTPUT.PUT_LINE('Dropped credential ' || UPPER(p_name));
        END IF;
    END drop_credential_if_exists;
BEGIN
    drop_credential_if_exists('POSTMAN_BASIC_HTTP_CRED');
    drop_credential_if_exists('HTTPBIN_BEARER_HTTP_CRED');
    drop_credential_if_exists('API_OAUTH_CLIENT_CRED');
    drop_credential_if_exists('DEMO_BEARER_CRED');
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP FUNCTION get_bearer_credential';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -4043 THEN
            RAISE;
        END IF;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE oauth_token_cache PURGE';
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE != -942 THEN
            RAISE;
        END IF;
END;
/
