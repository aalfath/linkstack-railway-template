# LinkStack for Railway: the official image, pinned by version and digest,
# plus a small start script that seeds the volume and creates the admin.
FROM linkstackorg/linkstack:v4.8.8@sha256:deba986fc1f7391af629c0bbcca67a1508284176bd3accf69d041ecc887dc7dd

USER root

# Keep a pristine copy of the app to seed an empty Railway volume at /htdocs.
# Apache listens on $PORT, TLS is Railway's job (ssl.conf is emptied, not deleted),
# and requests that reached Railway over HTTPS are treated as HTTPS.
RUN cp -a /htdocs /opt/linkstack \
 && sed -i 's/^Listen 80$/Listen ${PORT}/' /etc/apache2/httpd.conf \
 && grep -q '^Listen ${PORT}$' /etc/apache2/httpd.conf \
 && printf '\n# Railway: trust the edge proxy scheme\nSetEnvIf X-Forwarded-Proto "^https$" HTTPS=on\n' >> /etc/apache2/httpd.conf \
 && : > /etc/apache2/conf.d/ssl.conf

COPY --chmod=0755 railway-start.sh /usr/local/bin/railway-start.sh
COPY --chmod=0644 railway-bootstrap.php /usr/local/lib/linkstack-railway-bootstrap.php

ENV PORT=8080
EXPOSE 8080
WORKDIR /htdocs

CMD ["/usr/local/bin/railway-start.sh"]
