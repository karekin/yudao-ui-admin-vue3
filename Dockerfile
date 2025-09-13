# syntax=docker/dockerfile:1

############################
# 1) Build stage (Node 22.18.0)
############################
FROM node:22.18.0-alpine AS build
WORKDIR /app

# 仅拷贝依赖声明，利用缓存
COPY package*.json ./
RUN --mount=type=cache,target=/root/.npm npm ci

# 可选：通过 build-arg 注入 VITE_BASE_URL 与构建脚本
ARG VITE_BASE_URL=""
ARG BUILD_SCRIPT=build:dev

# 拷贝源码并构建
COPY . .
# 若传入 VITE_BASE_URL，则覆盖 .env.dev 中同名变量（后追加，最后一行优先生效）
RUN if [ -n "$VITE_BASE_URL" ]; then \
      printf "\nVITE_BASE_URL=%s\n" "$VITE_BASE_URL" >> .env.dev; \
    fi && \
    npm run $BUILD_SCRIPT

############################
# 2) Run stage (Nginx)
############################
FROM nginx:1.27-alpine

# 如使用前端路由 history 模式，需该配置；也开启 gzip
COPY nginx.conf /etc/nginx/conf.d/default.conf

# 将静态资源放进 Nginx 默认站点
COPY --from=build /app/dist/ /usr/share/nginx/html/

EXPOSE 80
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -qO- http://127.0.0.1/ >/dev/null 2>&1 || exit 1

CMD ["nginx", "-g", "daemon off;"]
