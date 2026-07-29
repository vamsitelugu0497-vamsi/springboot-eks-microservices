# Build stage
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn -B dependency:go-offline
COPY src ./src
RUN mvn -B clean package -DskipTests

# Runtime stage
# -------------------------
# Runtime Stage
# -------------------------
FROM eclipse-temurin:21-jre-alpine

RUN addgroup -g 10001 -S spring && \
    adduser -S -D -u 10001 -G spring spring

WORKDIR /app

COPY --from=build /app/target/user-service.jar app.jar

RUN chown -R 10001:10001 /app

USER 10001:10001

EXPOSE 8081

ENTRYPOINT ["java", "-XX:+UseContainerSupport", "-XX:MaxRAMPercentage=75.0", "-jar", "app.jar"]
