# Secure HTTP credentials and OAuth token reuse in Oracle Autonomous Database

This repository demonstrates how to call authenticated HTTPS endpoints from Oracle Autonomous Database without embedding passwords, client secrets, or reusable bearer tokens directly in application PL/SQL.

The examples use database credential objects created with `DBMS_CLOUD.CREATE_CREDENTIAL`.
The headers are created with  `UTL_HTTP.SET_CREDENTIAL` for HTTP Basic authentication, and `DBMS_CLOUD.SEND_REQUEST` with the `bearer://` URI scheme for bearer-token authentication.

The final example uses both credential-handling mechanisms in a complete OAuth 2.0 Client Credentials flow:

1. store the OAuth `client_id` and `client_secret` in a database credential;
2. request an access token with `grant_type=client_credentials` in the body and `client_secret_basic` authentication in the header;
3. store only the token timestamps in an application table;
4. store the access token in a separate database credential;
5. reuse the token while it remains valid;
6. request and store a new token when the existing token is close to expiry;
7. call the protected API without returning or printing the bearer token.

> The public endpoints and public demonstration credentials used here are not intended for production purposes.

## Why this matters

A common implementation pattern is to write credentials directly in PL/SQL, or store them in plain text in application tables:

```sql
UTL_HTTP.SET_HEADER(
    r     => l_request,
    name  => 'Authorization',
    value => 'Basic ' || l_encoded_username_and_password
);
```

or:

```sql
UTL_HTTP.SET_HEADER(
    r     => l_request,
    name  => 'Authorization',
    value => 'Bearer ' || l_access_token
);
```

That approach can expose secrets in source code, deployment scripts, code reviews, SQL history, logs, screenshots, and source-control repositories.

This project instead demonstrates a credential-object approach:

- credentials are created once with `DBMS_CLOUD.CREATE_CREDENTIAL`;
- the application refers to the credential by name;
- `UTL_HTTP.SET_CREDENTIAL` creates the Basic Authorization header without receiving the client secret as a PL/SQL parameter;
- `DBMS_CLOUD.SEND_REQUEST` reads the bearer token from the credential password field when the `bearer://` URI scheme is used;
- the OAuth token cache table stores timestamps, not the token itself.

## What the repository demonstrates

### 1. Basic authentication

Test endpoint:

```text
https://postman-echo.com/basic-auth
```

Public test credentials:

```text
username: postman
password: password
```

The repository compares:

- a request without credentials, expected to return HTTP 401;
- a manually constructed Basic Authorization header;
- a request using a stored database credential and `UTL_HTTP.SET_CREDENTIAL`.

The stored-credential request uses:

```sql
UTL_HTTP.SET_CREDENTIAL(
    r          => l_request,
    credential => 'POSTMAN_BASIC_HTTP_CRED',
    scheme     => 'BASIC'
);
```

This is equivalent to sending:

```http
Authorization: Basic base64(username:password)
```

without embedding the username and password in the request code.

### 2. Bearer authentication with a stored token

Test endpoint:

```text
https://httpbin.org/bearer
```

The HTTPBin endpoint confirms that a Bearer Authorization header was received. It accepts any non-empty test token and does not represent full OAuth token issuance or cryptographic token validation.

The repository compares:

- a request without a bearer token, expected to return HTTP 401;
- a manually constructed Bearer Authorization header;
- a token stored in a database credential and used with `DBMS_CLOUD.SEND_REQUEST`;
- updating the stored token with `DBMS_CLOUD.UPDATE_CREDENTIAL`.

The stored bearer request uses:

```sql
l_response := DBMS_CLOUD.SEND_REQUEST(
    credential_name => 'HTTPBIN_BEARER_HTTP_CRED',
    uri             => 'bearer://httpbin.org/bearer',
    method          => DBMS_CLOUD.METHOD_GET,
    headers         => '{"Accept":"application/json"}'
);
```

With `bearer://`, `DBMS_CLOUD` uses the value stored in the credential password field to generate:

```http
Authorization: Bearer <stored-token>
```

`UTL_HTTP.SET_CREDENTIAL(..., 'BEARER')` is intentionally not used because Bearer is not a supported `UTL_HTTP.SET_CREDENTIAL` authentication scheme.

### 3. OAuth 2.0 Client Credentials with token reuse

Authorization server token endpoint:

```text
https://demo.duendesoftware.com/connect/token
```

Protected API endpoint:

```text
https://demo.duendesoftware.com/api/test
```

Public demo client:

```text
client_id: m2m
client_secret: secret
scope: api
```

The token request uses `client_secret_basic`:

```http
POST /connect/token
Authorization: Basic base64(m2m:secret)
Content-Type: application/x-www-form-urlencoded

grant_type=client_credentials&scope=api
```

In PL/SQL, the Basic header is created from the stored credential:

```sql
UTL_HTTP.SET_CREDENTIAL(
    r          => l_request,
    credential => 'API_OAUTH_CLIENT_CRED',
    scheme     => 'BASIC'
);
```

The body contains:

```text
grant_type=client_credentials&scope=api
```

The `get_bearer_credential` function then:

- locks the cache row to avoid concurrent refreshes;
- checks `expires_at` with a configurable safety margin;
- returns the existing bearer credential name when the token is still valid;
- requests a new token when necessary;
- reads `access_token` and `expires_in` from the OAuth response;
- updates the bearer credential password with `DBMS_CLOUD.UPDATE_CREDENTIAL`;
- stores `obtained_at` and `expires_at` in `oauth_token_cache`;
- returns only the credential name, never the token.

The protected API is then called with:

```sql
l_response := DBMS_CLOUD.SEND_REQUEST(
    credential_name => l_credential_name,
    uri             => 'bearer://demo.duendesoftware.com/api/test',
    method          => DBMS_CLOUD.METHOD_GET,
    headers         => '{"Accept":"application/json"}'
);
```

## Network ACL prerequisite

Storing a credential does not grant network access.

Before any request is made, the application schema must have an Access Control Entry for every destination host. The demo grants the `http` privilege on TCP port 443 for:

- `postman-echo.com`;
- `httpbin.org`;
- `demo.duendesoftware.com`.

Run `sql/005_grant_network_access.sql` as `ADMIN` or another account allowed to manage network ACLs.

The scripts intentionally grant only the required hosts and port.




## Run order

### A. Grant and verify network access

Run as an administrator:

```text
sql/005_grant_network_access.sql
```

Run as the application schema:

```text
sql/010_check_network_access.sql
```

### B. Basic authentication

Run as the application schema:

```text
sql/020_basic_auth_without_credentials.sql
sql/025_basic_auth_manual_header.sql
sql/030_create_basic_credential.sql
sql/035_basic_auth_stored_credential.sql
```

Expected results:

- without credentials: HTTP 401;
- manual header: HTTP 200;
- stored credential: HTTP 200 and `{"authenticated":true}`.

### C. Static bearer-token authentication

Run as the application schema:

```text
sql/040_bearer_without_token.sql
sql/045_bearer_manual_header.sql
sql/050_create_static_bearer_credential.sql
sql/055_bearer_stored_credential.sql
sql/060_update_bearer_credential.sql
```

Expected results:

- without a token: HTTP 401;
- manual token: HTTP 200;
- stored token: HTTP 200;
- after credential update: HTTP 200 and the updated token echoed by the test service.

### D. OAuth Client Credentials and token reuse

Run as the application schema:

```text
sql/100_create_oauth_credentials.sql
sql/105_create_token_cache.sql
sql/110_get_bearer_credential.sql
sql/115_run_oauth_client_credentials_demo.sql
sql/120_show_token_cache.sql
```

Run `sql/115_run_oauth_client_credentials_demo.sql` twice.

First execution:

```text
No valid cached token
→ request a new access token
→ update DEMO_BEARER_CRED
→ store obtained_at and expires_at
→ call the protected API
```

Second execution before expiry:

```text
Token is still valid
→ reuse DEMO_BEARER_CRED
→ do not call the token endpoint again
→ call the protected API
```

For a faster refresh demonstration, replace the Duende client `m2m` with `m2m.short`. Its public demo token lifetime is approximately 75 seconds.



## Security notes

- Never commit real usernames, passwords, client secrets, access tokens, refresh tokens, wallets, private keys, or internal host names.
- The credentials in this repository belong to public test services only.
- Restrict ACLs to exact hosts and ports.
- Create credentials in the schema that owns and executes the PL/SQL code, or explicitly configure cross-schema privileges.
- A database credential is a schema object. Access to it should be granted only to the required schemas.
- Do not print complete access tokens with `DBMS_OUTPUT`.
- The token cache table deliberately contains timestamps only.
- Use a refresh margin instead of waiting until the exact expiry instant.
- Handle HTTP status codes before parsing response bodies.
- Public test endpoints can change or become unavailable.

## Autonomous Database and customer-managed Oracle Database

This repository is designed and tested conceptually for Oracle Autonomous Database, where `DBMS_CLOUD` is supplied by the service.

`DBMS_CLOUD` can also be installed on supported customer-managed Oracle Database releases, but it is not necessarily pre-installed or configured. Installation steps and feature availability depend on the database release and patch level. Validate `DBMS_CLOUD.CREATE_CREDENTIAL`, `DBMS_CLOUD.UPDATE_CREDENTIAL`, `DBMS_CLOUD.SEND_REQUEST`, and the required URI schemes in the target environment before presenting the scripts as portable to on-premises databases.

## Cleanup

Run:

```text
sql/900_cleanup.sql
```

The cleanup script removes the demo credentials, token cache table, and function. Network ACL removal should be performed by an administrator only when the grants are no longer needed.

## Documentation references

### Oracle documentation

- [Call Web Services from Autonomous AI Database](https://docs.oracle.com/en/cloud/paas/autonomous-database/serverless/adbsb/call-web-services.html)
- [`UTL_HTTP` — Oracle AI Database PL/SQL Packages and Types Reference](https://docs.oracle.com/en/database/oracle/oracle-database/26/arpls/UTL_HTTP.html)
- [`DBMS_CLOUD` — Oracle AI Database PL/SQL Packages and Types Reference](https://docs.oracle.com/en/database/oracle/oracle-database/26/arpls/DBMS_CLOUD.html)
- [`DBMS_NETWORK_ACL_ADMIN` — Oracle AI Database PL/SQL Packages and Types Reference](https://docs.oracle.com/en/database/oracle/oracle-database/26/arpls/DBMS_NETWORK_ACL_ADMIN.html)

### Test services

- [Postman Echo API documentation](https://learning.postman.com/docs/reference/developer-resources/echo-api/)
- [Postman Echo Basic Authentication endpoint](https://postman-echo.com/basic-auth)
- [HTTPBin documentation](https://httpbin.org/)
- [HTTPBin Bearer Authentication endpoint](https://httpbin.org/bearer)
- [Duende IdentityServer public demo](https://demo.duendesoftware.com/)

### OAuth 2.0 specifications

- [RFC 6749 — The OAuth 2.0 Authorization Framework](https://www.rfc-editor.org/rfc/rfc6749.html)
- [RFC 6750 — The OAuth 2.0 Authorization Framework: Bearer Token Usage](https://www.rfc-editor.org/rfc/rfc6750.html)

## License

This project is licensed under the MIT License.
