# ── Stage 1: Build ──────────────────────────────────────────────────────────
FROM eclipse-temurin:21-jdk-alpine AS builder

WORKDIR /app

# Install maven
RUN apk add --no-cache maven

# Cache dependencies first
COPY pom.xml .
RUN mvn dependency:go-offline -q

# Build the application
COPY src ./src
RUN mvn clean package -DskipTests -q

# ── Stage 2: Runtime ─────────────────────────────────────────────────────────
FROM eclipse-temurin:21-jre-alpine AS runner

WORKDIR /app

RUN apk add --no-cache dumb-init

# Non-root user for security
RUN addgroup -g 1001 -S eggova && adduser -S eggova -u 1001 -G eggova

COPY --from=builder --chown=eggova:eggova /app/target/eggova-backend-*.jar app.jar

USER eggova

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD wget -qO- http://localhost:8080/api/health || exit 1

ENTRYPOINT ["dumb-init", "--"]
CMD ["java", "-jar", "app.jar"]
