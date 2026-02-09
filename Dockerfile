# Custom CI image for ExitZero Flutter builds
# Pre-caches Android SDK, Gradle, and dependencies to speed up builds

FROM ghcr.io/cirruslabs/flutter:latest

# Versions (update these when upgrading)
ENV GRADLE_VERSION=8.14
ENV ANDROID_COMPILE_SDK=35
# Install multiple build-tools versions that Flutter might need
ENV ANDROID_BUILD_TOOLS_1=35.0.0
ENV ANDROID_BUILD_TOOLS_2=35.0.1

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
    "platforms;android-34" \
    "build-tools;${ANDROID_BUILD_TOOLS_1}" \
    "build-tools;${ANDROID_BUILD_TOOLS_2}" \
    "platform-tools" \
    "cmdline-tools;latest" \
    "cmake;3.22.1" \
    "ndk;27.0.12077973"

# Pre-warm Flutter
RUN flutter precache --android

# Create a dummy Flutter project and run a full release build to cache everything
WORKDIR /tmp/warmup
RUN flutter create --platforms=android warmup_app && \
    cd warmup_app && \
    flutter pub get && \
    flutter build apk --release || true && \
    cd / && rm -rf /tmp/warmup

# Clean up to reduce image size
RUN rm -rf /root/.gradle/caches/transforms-* && \
    rm -rf /root/.gradle/daemon

WORKDIR /builds
