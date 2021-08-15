#!/bin/bash
#================================================
# script borrow from:
# java: https://github.com/AdoptOpenJDK/openjdk-docker/blob/master/11/jdk/debian/Dockerfile.hotspot.releases.full
# maven: https://github.com/carlossg/docker-maven/blob/b243010db790a1ab8f6a43d26ae86a76cba86b55/adoptopenjdk-11/Dockerfile
#======================JDK==========================
set -eux
JAVA_VERSION="jdk-11.0.10+9"
CURRENT_FOLDER=`pwd`
ARCH="$(dpkg --print-architecture)"
case "${ARCH}" in \
       aarch64|arm64) \
         ESUM='420c5d1e5dc66b2ed7dedd30a7bdf94bfaed10d5e1b07dc579722bf60a8114a9'; \
         BINARY_URL='https://github.com/AdoptOpenJDK/openjdk11-binaries/releases/download/jdk-11.0.10%2B9/OpenJDK11U-jdk_aarch64_linux_hotspot_11.0.10_9.tar.gz'; \
         ;; \
       armhf|armv7l) \
         ESUM='34908da9c200f5ef71b8766398b79fd166f8be44d87f97510667698b456c8d44'; \
         BINARY_URL='https://github.com/AdoptOpenJDK/openjdk11-binaries/releases/download/jdk-11.0.10%2B9/OpenJDK11U-jdk_arm_linux_hotspot_11.0.10_9.tar.gz'; \
         ;; \
       ppc64el|ppc64le) \
         ESUM='e1d130a284f0881893711f17df83198d320c16f807de823c788407af019b356b'; \
         BINARY_URL='https://github.com/AdoptOpenJDK/openjdk11-binaries/releases/download/jdk-11.0.10%2B9/OpenJDK11U-jdk_ppc64le_linux_hotspot_11.0.10_9.tar.gz'; \
         ;; \
       s390x) \
         ESUM='b55e5d774bcec96b7e6ffc8178a17914ab151414f7048abab3afe3c2febb9a20'; \
         BINARY_URL='https://github.com/AdoptOpenJDK/openjdk11-binaries/releases/download/jdk-11.0.10%2B9/OpenJDK11U-jdk_s390x_linux_hotspot_11.0.10_9.tar.gz'; \
         ;; \
       amd64|x86_64) \
         ESUM='ae78aa45f84642545c01e8ef786dfd700d2226f8b12881c844d6a1f71789cb99'; \
         BINARY_URL='https://github.com/AdoptOpenJDK/openjdk11-binaries/releases/download/jdk-11.0.10%2B9/OpenJDK11U-jdk_x64_linux_hotspot_11.0.10_9.tar.gz'; \
         ;; \
       *) \
         echo "Unsupported arch: ${ARCH}"; \
         exit 1; \
         ;; \
esac; \
curl -LfsSo /tmp/openjdk.tar.gz ${BINARY_URL}
echo "${ESUM} */tmp/openjdk.tar.gz" | sha256sum -c -
mkdir -p /opt/java/openjdk
cd /opt/java/openjdk
tar -xf /tmp/openjdk.tar.gz --strip-components=1
rm -rf /tmp/openjdk.tar.gz
#==========================Maven======================
MAVEN_VERSION="3.6.3"
SHA="c35a1803a6e70a126e80b2b3ae33eed961f83ed74d18fcd16909b2d44d7dada3203f1ffe726c17ef8dcca2dcaa9fca676987befeadc9b9f759967a8cb77181c0"
BASE_URL=https://apache.osuosl.org/maven/maven-3/${MAVEN_VERSION}/binaries

mkdir -p /opt/maven /opt/maven/ref \
  && curl -fsSL -o /tmp/apache-maven.tar.gz ${BASE_URL}/apache-maven-${MAVEN_VERSION}-bin.tar.gz \
  && echo "${SHA}  /tmp/apache-maven.tar.gz" | sha512sum -c - \
  && tar -xzf /tmp/apache-maven.tar.gz -C /opt/maven --strip-components=1 \
  && rm -f /tmp/apache-maven.tar.gz \
  && ln -f -s /opt/maven/bin/mvn /usr/bin/mvn

echo "export JAVA_HOME=/opt/java/openjdk" >> /etc/profile
echo "export JRE_HOME=\$JAVA_HOME/jre" >> /etc/profile
echo "export MAVEN_HOME=/opt/maven" >> /etc/profile
echo "export MAVEN_CONFIG=~/.m2" >> /etc/profile
echo "export PATH=\$JAVA_HOME/bin:\$PATH" >> /etc/profile
source /etc/profile
cp -f "${CURRENT_FOLDER}/settings.xml" /opt/maven/ref/
