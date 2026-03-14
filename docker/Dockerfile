# Stage 1: Build
FROM eclipse-temurin:17-jdk AS builder
WORKDIR /app
COPY app/pom.xml .
COPY app/mvnw .
COPY app/.mvn .mvn
COPY app/src src
RUN chmod +x mvnw && ./mvnw package -DskipTests

# Stage 2: Run
FROM eclipse-temurin:17-jre
WORKDIR /app
COPY --from=builder /app/target/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
