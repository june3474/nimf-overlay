# Ubuntu and every Qt source archive are digest-pinned. Rebuild this image only
# when this file, the plugin build scripts, or config/qt5-sdks.tsv changes.
FROM ubuntu:20.04@sha256:c664f8f86ed5a386b0a340d981b8f81714e21a8b9c73f658c4bea56aa179d54a

ARG QT_MINOR
ARG QT_VERSION
ARG QT_SHA256
ARG QT_URL

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bison build-essential ca-certificates curl flex gperf libglib2.0-dev \
      libfontconfig1-dev libfreetype6-dev libx11-dev libxext-dev \
      libxrender-dev patch perl pkg-config python3 python-is-python3 xz-utils \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY containers/qt5-sdk/patches /tmp/qt5-sdk-patches
RUN test -n "${QT_MINOR}" \
 && test -n "${QT_VERSION}" \
 && test -n "${QT_SHA256}" \
 && test -n "${QT_URL}" \
 && curl -fsSLo qtbase.tar.xz "${QT_URL}" \
 && echo "${QT_SHA256}  qtbase.tar.xz" | sha256sum -c - \
 && mkdir qtbase \
 && tar -xJf qtbase.tar.xz --strip-components=1 -C qtbase \
 && if [ "${QT_MINOR}" = 5.11 ]; then \
      patch -d qtbase -p1 < /tmp/qt5-sdk-patches/qt-5.11-gcc9.patch; \
    fi \
 && cd qtbase \
 && ./configure \
      -prefix "/opt/qt/${QT_VERSION}" \
      -opensource -confirm-license -release -shared \
      -platform linux-g++ -nomake examples -nomake tests \
      -no-opengl -no-xcb -no-dbus -no-glib -no-icu -no-cups \
      -no-openssl -no-pch \
 && make -j"$(nproc)" \
 && make install \
 && rm -rf /build/qtbase /build/qtbase.tar.xz

ENV PATH="/opt/qt/${QT_VERSION}/bin:${PATH}"
ENV QMAKE="/opt/qt/${QT_VERSION}/bin/qmake"
ENV QT_VERSION="${QT_VERSION}"

COPY scripts/build-qt5-plugin.sh scripts/test-qt5-plugin.sh scripts/qt-plugin-minor.sh /usr/local/bin/
RUN chmod 0755 /usr/local/bin/build-qt5-plugin.sh /usr/local/bin/test-qt5-plugin.sh \
    /usr/local/bin/qt-plugin-minor.sh

ENTRYPOINT ["/usr/local/bin/build-qt5-plugin.sh"]
