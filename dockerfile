# Build stage
FROM node:16-alpine AS builder

WORKDIR /app

# Clone the repository
RUN apk add --no-cache git && \
    git clone https://github.com/CursedHardware/atorch-console.git . && \
    apk del git

# Install dependencies
RUN npm ci

# Build the application
RUN npm run build

# Runtime stage
FROM nginx:alpine

# Generate self-signed certificate for HTTPS
RUN apk add --no-cache openssl && \
    mkdir -p /etc/nginx/ssl && \
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/private.key \
    -out /etc/nginx/ssl/certificate.crt \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost" && \
    apk del openssl

# Copy built files to nginx
COPY --from=builder /app/dist /usr/share/nginx/html

# Create nginx configuration with HTTPS only
RUN printf '%s\n' \
'server {' \
'    listen 443 ssl;' \
'    server_name _;' \
'    ssl_certificate /etc/nginx/ssl/certificate.crt;' \
'    ssl_certificate_key /etc/nginx/ssl/private.key;' \
'    location / {' \
'        root /usr/share/nginx/html;' \
'        index index.html;' \
'        try_files $uri $uri/ /index.html;' \
'    }' \
'    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {' \
'        root /usr/share/nginx/html;' \
'        expires 1y;' \
'        add_header Cache-Control "public, immutable";' \
'    }' \
'}' > /etc/nginx/conf.d/default.conf

EXPOSE 443

CMD ["nginx", "-g", "daemon off;"]

