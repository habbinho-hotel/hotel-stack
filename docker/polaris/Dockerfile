# syntax=docker/dockerfile:1

# ---- build: compila o JAR com Maven e JDK 21 ----
FROM eclipse-temurin:21 AS build
RUN apt-get update && apt-get install -y maven && rm -rf /var/lib/apt/*

WORKDIR /build/Emulator
COPY polaris-emulator/Emulator/ ./

RUN mvn -B -ntp clean package -DskipTests \
 && cp target/Polaris-*-jar-with-dependencies.jar /build/polaris.jar

# ---- runtime: só o JRE + o JAR ----
FROM eclipse-temurin:25-jre
WORKDIR /app
COPY --from=build /build/polaris.jar /app/polaris.jar
COPY ["polaris-emulator/config example/config.ini.example", "/app/config.ini.example"]
COPY docker/polaris/entrypoint.sh /entrypoint.sh
RUN mkdir -p /data && chown -R 1000:1000 /app /data
USER 1000:1000
EXPOSE 2096
ENTRYPOINT ["sh", "/entrypoint.sh"]