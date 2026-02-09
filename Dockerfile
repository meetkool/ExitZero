# Custom CI image for ExitZero Flutter builds
# Pre-caches Android SDK, Gradle, and dependencies to speed up builds

FROM ghcr.io/cirruslabs/flutter:latest

# Versions (update these when upgrading)
ENV GRADLE_VERSION=8.14
ENV ANDROID_COMPILE_SDK=35
ENV ANDROID_BUILD_TOOLS=35.0.1

# Pre-download Gradle distribution
RUN mkdir -p /opt/gradle && \
    curl -fsSL "https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-all.zip" \
    -o /tmp/gradle.zip && \
    unzip -q /tmp/gradle.zip -d /opt/gradle && \
    rm /tmp/gradle.zip

ENV GRADLE_HOME=/opt/gradle/gradle-${GRADLE_VERSION}
ENV PATH="${GRADLE_HOME}/bin:${PATH}"

# Accept Android SDK licenses and install required components
RUN yes | sdkmanager --licenses && \
    sdkmanager --update && \
    sdkmanager \
    "platforms;android-${ANDROID_COMPILE_SDK}" \
    "build-tools;${ANDROID_BUILD_TOOLS}" \
    "platform-tools" \
    "cmdline-tools;latest"

# Pre-warm Flutter
RUN flutter precache --android

# Create a dummy project to pre-download Gradle plugins and dependencies
WORKDIR /tmp/warmup
RUN flutter create --platforms=android warmup_app && \
    cd warmup_app && \
    flutter pub get && \
    cd android && \
    ./gradlew --no-daemon tasks || true && \
    cd / && rm -rf /tmp/warmup

WORKDIR /builds
