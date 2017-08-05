FROM logstash

VOLUME /var/log/


ENV ELASTICSEARCH_HOST elasticsearch

ENV ACCESS_LOG_FILE_NAME access.log
ENV ERROR_LOG_FILE_NAME error.log

COPY docker-entrypoint.sh /

RUN chmod +x /docker-entrypoint.sh

CMD ["bash","/docker-entrypoint.sh"]