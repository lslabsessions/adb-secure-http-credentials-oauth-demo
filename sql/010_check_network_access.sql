-- Run as the application schema after the admin grants the ACLs.

SELECT host,
       lower_port,
       upper_port,
       privilege,
       status
  FROM user_host_aces
 WHERE host IN (
           'postman-echo.com',
           'httpbin.org',
           'demo.duendesoftware.com'
       )
 ORDER BY host, lower_port, upper_port, privilege;
