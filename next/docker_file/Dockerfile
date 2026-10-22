# Development build for Next.js application with hot reload
FROM node:22-alpine

WORKDIR /app

# Install curl for healthcheck
RUN apk add --no-cache curl

# Install dependencies
# Copy only package files first for better layer caching
COPY package.json package-lock.json ./
RUN npm install

# Copy application source code
# Note: .dockerignore excludes node_modules/ and .next/ to ensure clean build
# In development, this will be overridden by volume mount from docker-compose
COPY . .

EXPOSE 3000

ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

# Run in development mode for hot reload
CMD ["npm", "run", "dev"]
