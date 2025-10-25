# 使用官方 Mongo 7
FROM mongo:7

ENV TZ=UTC

COPY init.sh /init.sh
RUN chmod +x /init.sh

EXPOSE 27017

CMD ["/init.sh"]
