ARG NGINX_VERSION=nginx:1.29.2-alpine
FROM ${NGINX_VERSION}

# 設定預設環境字集
ENV LANG=C.UTF-8

# Install logrotate
RUN apk update && apk add --no-cache logrotate nano vim