###############################################################################
# ── build stage – placeholder only ───────────────────────────────────────────
###############################################################################
FROM node:18-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .

# put a harmless token in the code
ARG VITE_API_URL=__VITE_API_URL__
ENV VITE_API_URL=$VITE_API_URL
RUN npm run build

###############################################################################
# ── runtime stage – replace token ────────────────────────────────────────────
###############################################################################
FROM node:18-alpine
WORKDIR /srv
COPY --from=build /app/dist .

# Install serve for serving static files
RUN npm install -g serve

# tiny script replaces the token with the real value **from ECS env**
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 5173
ENTRYPOINT ["/entrypoint.sh"]

