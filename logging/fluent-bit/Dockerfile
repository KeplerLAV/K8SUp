FROM cr.fluentbit.io/fluent/fluent-bit:2.2.0
WORKDIR /fluent-bit/etc/

# Docker cherchera maintenant ces fichiers dans logging/fluent-bit/
COPY fluent-bit.conf .
COPY parsers.conf .

EXPOSE 5044
CMD ["/fluent-bit/bin/fluent-bit", "-c", "/fluent-bit/etc/fluent-bit.conf"]