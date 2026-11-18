# Use the jlesage/baseimage-gui:ubuntu-26.04-v4.14 as base image
FROM jlesage/baseimage-gui:ubuntu-26.04-v4.14 AS build

LABEL maintainer="Bjoern Gruening <bjoern.gruening@gmail.com>"

# Install build prerequisites.
# Note: add-pkg is the baseimage's package helper. It prepares the environment
# dpkg post-install scripts expect (user/group database, /config/log), which
# do not exist in the base image before container startup, and cleans up after.
RUN add-pkg ca-certificates wget unzip python3-pip

# Add the QGIS apt repository (latest stable release, QGIS 4).
RUN mkdir -p /etc/apt/keyrings && \
    wget -q -O /etc/apt/keyrings/qgis-archive-keyring.gpg https://download.qgis.org/downloads/qgis-archive-keyring.gpg && \
    echo "Types: deb deb-src" > /etc/apt/sources.list.d/qgis.sources && \
    echo "URIs: https://qgis.org/debian" >> /etc/apt/sources.list.d/qgis.sources && \
    echo "Suites: resolute" >> /etc/apt/sources.list.d/qgis.sources && \
    echo "Architectures: amd64" >> /etc/apt/sources.list.d/qgis.sources && \
    echo "Components: main" >> /etc/apt/sources.list.d/qgis.sources && \
    echo "Signed-By: /etc/apt/keyrings/qgis-archive-keyring.gpg" >> /etc/apt/sources.list.d/qgis.sources

# Install QGIS and the Python dependencies of the FinBIF plugin.
RUN add-pkg \
        qgis \
        qgis-plugin-grass \
        python3-geopandas \
        python3-pyarrow \
        python3-pandas \
        python3-numpy \
        python3-shapely \
        python3-requests \
        python3-certifi \
        python3-urllib3 && \
    pip3 install --break-system-packages future qgis-plugin-manager

COPY startapp.sh /startapp.sh
RUN chmod +x /startapp.sh && \
    mkdir -p /app/qgis

# Set the name of the application.
ENV APP_NAME="QGIS"
ENV APP_VERSION="4.2"

ENV KEEP_APP_RUNNING=0

ENV TAKE_CONFIG_OWNERSHIP=1

# Set environment
ENV JAVA_HOME=/opt/jdk
ENV PATH=${PATH}:${JAVA_HOME}/bin
WORKDIR /app/qgis

# NOTE: no explicit 'USER root' here: BuildKit resolves a USER *name* against
# /etc/passwd, which is a dangling symlink in the base image until container
# startup (the default user is root anyway).

# Add plugins to the QGIS tool (trends.earth and FinBIF for now).
# Note: Hugin QGIS was dropped, its metadata caps at QGIS 3.99 and it is
# incompatible with QGIS 4.
RUN . /opt/base/bin/cmn-pkg && init_env &&\
    # The base image does not set HOME; without it QGIS resolves its profile
    # directory to //.local/share (empty HOME) and finds nothing. Root's real
    # home is where the plugins are installed below.
    export HOME=/root &&\
    # QGIS 4 installs its Python modules under /usr/share/qgis/python, which is
    # not on the system Python's path (the qgis binaries' wrappers set it, but
    # standalone python3 - e.g. qgis-plugin-manager - needs it explicitly).
    export PYTHONPATH=/usr/share/qgis/python${PYTHONPATH:+:$PYTHONPATH} &&\
    pip3 install --break-system-packages --no-deps qgis-plugin-manager &&\
    # special trends earth manip to counter path issues (should contact the authors to fix this in their code)
    mkdir -p /root/trends_earth_data/reports/outputs/ && \
    # trends earth again
    mkdir /root/trends_earth_data/reports/templates && \
    # trends earth again
    touch /root/trends_earth_data/reports/templates/templates.json && \
    #Back to the general plugin installation
    # Note: QGIS 4 stores user profiles under ~/.local/share/QGIS/QGIS4
    # (QGIS 3 used ~/.local/share/QGIS/QGIS3).
    mkdir -p /root/.local/share/QGIS/QGIS4/profiles/default/python/plugins/ &&\
    cd /root/.local/share/QGIS/QGIS4/profiles/default/python/plugins/ &&\
    qgis-plugin-manager init && \
    qgis-plugin-manager update && \
    qgis-plugin-manager install 'trends.earth' &&\
    # FinBIF plugin: fetched from plugins.qgis.org, pinned to the latest stable release
    wget -q -O /tmp/FinBIF_QGIS_Plugin.zip https://plugins.qgis.org/plugins/FinBIF_QGIS_Plugin/version/2.3/download/ && \
    unzip -q /tmp/FinBIF_QGIS_Plugin.zip -d /root/.local/share/QGIS/QGIS4/profiles/default/python/plugins/ && \
    rm /tmp/FinBIF_QGIS_Plugin.zip

# Enable plugins in the profile settings.
RUN . /opt/base/bin/cmn-pkg && init_env &&\
    export HOME=/root PYTHONPATH=/usr/share/qgis/python QT_QPA_PLATFORM=offscreen &&\
    qgis_process.bin plugins enable LDMP &&\
    unset QT_QPA_PLATFORM &&\
    # FinBIF is a GUI-only plugin: 'qgis_process plugins enable' manages to enable it,
    # but then fails to *start* it, because initGui() needs a real QgisInterface which
    # the headless qgis_process does not provide -> the setting would not be persisted.
    # Instead, enable it directly in the profile settings (the ini is created by the
    # successful enable call above).
    INI=$(find /root/.local/share/QGIS/QGIS4/profiles/default -name 'QGIS*.ini' -print -quit) &&\
    test -n "$INI" &&\
    sed -i '/^\[PythonPlugins\]/a FinBIF_QGIS_Plugin=true' "$INI" &&\
    grep -q '^FinBIF_QGIS_Plugin=true' "$INI"

WORKDIR /config
