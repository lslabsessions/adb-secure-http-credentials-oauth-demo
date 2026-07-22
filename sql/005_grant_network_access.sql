-- Run as ADMIN or another account allowed to manage network ACLs.
-- Replace APP_USER with the schema that will execute UTL_HTTP.

SET SERVEROUTPUT ON

DEFINE TARGET_SCHEMA = APP_USER

DECLARE
    l_schema_name VARCHAR2(128) := UPPER('&TARGET_SCHEMA');

    PROCEDURE grant_http_access(p_host IN VARCHAR2) IS
    BEGIN
        DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
            host       => p_host,
            lower_port => 443,
            upper_port => 443,
            ace        => XS$ACE_TYPE(
                privilege_list => XS$NAME_LIST('http'),
                principal_name => l_schema_name,
                principal_type => XS_ACL.PTYPE_DB
            )
        );

        DBMS_OUTPUT.PUT_LINE(
            'Granted HTTP access on ' || p_host || ':443 to ' || l_schema_name
        );
    END grant_http_access;
BEGIN
    grant_http_access('postman-echo.com');
    grant_http_access('httpbin.org');
    grant_http_access('demo.duendesoftware.com');
END;
/
