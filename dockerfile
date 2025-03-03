# 设置默认平台为 linux/amd64
ARG TARGETPLATFORM=linux/amd64

# 使用指定平台的基础镜像
FROM --platform=$TARGETPLATFORM node:22-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-distutils \
    python3-dev \
    make \
    g++ \
    gcc \
    git \
    libssl-dev \
    build-essential \
    pkg-config

# RUN apt-get install -y openssl

WORKDIR /app

ENV NEXT_PRIVATE_STANDALONE=true

COPY package.json pnpm-lock.yaml ./
COPY prisma ./

# 安装 pnpm 并根据 USE_MIRROR 变量选择是否使用镜像源
RUN npm install -g pnpm@9.12.2 --registry=https://registry.npmmirror.com && \
    if [ "$USE_MIRROR" = "true" ]; then \
    echo "Using mirror registry..."; \
    fi && \
    pnpm install --registry=https://registry.npmmirror.com

COPY . .
RUN pnpm build
RUN pnpm build-seed

FROM --platform=$TARGETPLATFORM node:22-slim AS runner

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl \
    tzdata \
    openssl \
    pkg-config

COPY .npmrc /root/.npmrc
RUN npm install -g prisma --registry=https://registry.npmmirror.com
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

# COPY --from=builder /app/node_modules/@libsql/linux-x64-gnu ./node_modules/@libsql/linux-x64-gnu

# 根据目标平台选择合适的二进制库
# RUN if [ "$TARGETPLATFORM" = "linux/amd64" ]; then \
#     cp -r /app/node_modules/@libsql/linux-x64-gnu ./node_modules/@libsql/linux-x64-gnu; \
#     elif [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
#     cp -r /app/node_modules/@libsql/linux-arm64-gnu ./node_modules/@libsql/linux-arm64-gnu; \
#     fi

ENV NODE_ENV=production \
    PORT=1111

EXPOSE 1111

CMD ["sh", "-c", "prisma migrate deploy && node seed.js && node server.js"]
