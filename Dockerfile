FROM public.ecr.aws/docker/library/node:26-alpine

RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app 

COPY ./app/package*.json ./

RUN npm ci --only=production

COPY app/index.js ./

COPY ./app/public/ ./public

USER appuser

EXPOSE 8080

ENV APP_VERSION=1.0.0

CMD ["node", "index.js"]