FROM nginx:1.27-alpine

# Replace the default site with our own content
RUN rm -rf /usr/share/nginx/html/*
COPY html/ /usr/share/nginx/html/

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -qO- http://localhost/ > /dev/null || exit 1

CMD ["nginx", "-g", "daemon off;"]
