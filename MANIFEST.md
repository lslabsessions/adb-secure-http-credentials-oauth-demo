# Project manifest

## Purpose

Demonstrate how to securely authenticate outbound HTTP requests from Oracle Autonomous Database by using database credential objects instead of embedding reusable secrets in PL/SQL source code or storing them in plain text in application tables.

## Covered scenarios

1. HTTP Basic authentication without credentials: expected failure.
2. HTTP Basic authentication with a manually generated Authorization header.
3. HTTP Basic authentication with `UTL_HTTP.SET_CREDENTIAL`.
4. Bearer authentication without a token: expected failure.
5. Bearer authentication with a manual Authorization header.
6. Bearer authentication with a token stored in a database credential and `DBMS_CLOUD.SEND_REQUEST`.
7. Updating a stored bearer token.
8. OAuth 2.0 Client Credentials using `client_secret_basic`.
9. Token expiry tracking and concurrency-safe token refresh.
10. Reuse of the stored bearer credential while the token remains valid.

## Public test services

- Postman Echo: Basic authentication.
- HTTPBin: Bearer header transport test.
- Duende IdentityServer Demo: OAuth token.

