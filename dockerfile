FROM node:22-slim AS base

# 使用更快的镜像源（可选）
ARG USE_MIRROR=false
RUN if [ "$USE_MIRROR" = "true" ] && [ -f /etc/apt/sources.list ]; then \
    sed -i 's|http://deb.debian.org|http://ftp.cn.debian.org|g' /etc/apt/sources.list; \
    fi && \
    if [ "$UPDATE" = "true" ]; then \
        apt-get update && apt-get install -y --no-install-recommends \
        curl \
        tzdata \
        openssl \
        python3 \
        python3-distutils \
        python3-dev \
        make \
        g++ \
        gcc \
        git \
        libssl-dev \
        build-essential && \
        apt-get clean && rm -rf /var/lib/apt/lists/*; \
        fi
# 构建阶段
FROM base AS builder

WORKDIR /app

ENV NEXT_PRIVATE_STANDALONE=true

COPY package.json pnpm-lock.yaml ./
COPY prisma ./

# RUN npm install -g pnpm@9.12.2 && \
#     if [ "$USE_MIRROR" = "true" ]; then \
#     echo "Using mirror registry..." && \
#     npm install -g nrm && \
#     nrm use taobao; \
#     fi && \
#     pnpm install

# COPY . .
# RUN pnpm build
# RUN pnpm build-seed

# RUN npm install -g yarn && \
RUN yarn install && \
RUN npm install prisma --global

COPY . .
RUN yarn build
RUN yarn build-seed



# 运行阶段
FROM base AS runner

WORKDIR /app

COPY --from=builder /app/next.config.js ./
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/prisma ./prisma
COPY --from=builder /app/package.json ./
COPY --from=builder /app/seed.js ./seed.js
COPY --from=builder /app/resetpassword.js ./resetpassword.js
COPY --from=builder /app/node_modules/@libsql/linux-arm64-gnu ./node_modules/@libsql/linux-arm64-gnu

ENV NODE_ENV=production
ENV PORT=1111

EXPOSE 1111

CMD ["sh", "-c", "prisma migrate deploy && node seed.js && node server.js"]
