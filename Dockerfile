# Use the jlesage/baseimage-gui:ubuntu-24.04-v4.14 as base image
FROM jlesage/baseimage-gui:ubuntu-24.04-v4.14 AS build

LABEL maintainer="Bjoern Gruening <bjoern.gruening@gmail.com>"

# Install build prerequisites.
# Note: add-pkg is the baseimage's package helper.
RUN add-pkg ca-certificates wget unzip python3-pip

# Add the QGIS apt repository.
# The LTR repo is used because Ubuntu 24.04 (noble) only ships QGIS < 4
# (QGIS 4 requires Qt6).
RUN mkdir -p /etc/apt/keyrings && \
    wget -q -O /etc/apt/keyrings/qgis-archive-keyring.gpg https://download.qgis.org/downloads/qgis-archive-keyring.gpg && \
    echo "Types: deb deb-src" > /etc/apt/sources.list.d/qgis.sources && \
    echo "URIs: https://qgis.org/debian-ltr" >> /etc/apt/sources.list.d/qgis.sources && \
    echo "Suites: noble" >> /etc/apt/sources.list.d/qgis.sources && \
    echo "Architectures: amd64" >> /etc/apt/sources.list.d/qgis.sources && \
    echo "Components: main" >> /etc/apt/sources.list.d/qgis.sources && \
    echo "Signed-By: /etc/apt/keyrings/qgis-archive-keyring.gpg" >> /etc/apt/sources.list.d/qgis.sources

# Install QGIS and the Python dependencies of the FinBIF plugin.
RUN add-pkg \
        qgis \
        qgis-plugin-grass \
        python3-geopandas \
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
ENV APP_VERSION="3.44"

ENV KEEP_APP_RUNNING=0

ENV TAKE_CONFIG_OWNERSHIP=1

# Set environment
ENV JAVA_HOME=/opt/jdk
ENV PATH=${PATH}:${JAVA_HOME}/bin
WORKDIR /app/qgis

# NOTE: no explicit 'USER root' here: BuildKit resolves a USER *name* against
# /etc/passwd, which is a dangling symlink in the base image until container
# startup (the default user is root anyway).

# Add plugins to the QGIS tool (trends.earth, Hugin and FinBIF for now)
# You can just download here the zip folder for your plugins
RUN . /opt/base/bin/cmn-pkg && init_env &&\
    pip3 install --break-system-packages --no-deps qgis-plugin-manager &&\
    # special trends earth manip to counter path issues (should contact the authors to fix this in their code)
    mkdir -p /root/trends_earth_data/reports/outputs/ && \
    # trends earth again
    mkdir /root/trends_earth_data/reports/templates && \
    # trends earth again
    touch /root/trends_earth_data/reports/templates/templates.json && \
    #Back to the general plugin installation
    mkdir -p /root/.local/share/QGIS/QGIS3/profiles/default/python/plugins/ &&\
    cd /root/.local/share/QGIS/QGIS3/profiles/default/python/plugins/ &&\
    qgis-plugin-manager init && \
    qgis-plugin-manager update && \
    ## Hugin QGIS is flagged experimental on plugins.qgis.org -> needs --pre
    qgis-plugin-manager install 'Hugin QGIS' --pre && \
    qgis-plugin-manager install 'trends.earth' &&\
    # FinBIF plugin: fetched from plugins.qgis.org, pinned to the latest stable release
    wget -q -O /tmp/FinBIF_QGIS_Plugin.zip https://plugins.qgis.org/plugins/FinBIF_QGIS_Plugin/version/2.3/download/ && \
    unzip -q /tmp/FinBIF_QGIS_Plugin.zip -d /root/.local/share/QGIS/QGIS3/profiles/default/python/plugins/ && \
    rm /tmp/FinBIF_QGIS_Plugin.zip && \
    mkdir -p ${HOME}/.local/share/ &&\
    export QT_QPA_PLATFORM=offscreen &&\
    qgis_process.bin plugins enable hugin_qgis &&\
    # Next is trends earth plugin (different name don't know why)
    qgis_process.bin plugins enable LDMP &&\
    unset QT_QPA_PLATFORM &&\
    # FinBIF is a GUI-only plugin: 'qgis_process plugins enable' manages to enable it,
    # but then fails to *start* it, because initGui() needs a real QgisInterface which
    # the headless qgis_process does not provide -> the setting would not be persisted.
    # Instead, enable it directly in the profile settings (the ini is created by the
    # two successful enable calls above).
    sed -i '/^\[PythonPlugins\]/a FinBIF_QGIS_Plugin=true' \
        /root/.local/share/QGIS/QGIS3/profiles/default/QGIS/QGIS3.ini &&\
    grep -q '^FinBIF_QGIS_Plugin=true' \
        /root/.local/share/QGIS/QGIS3/profiles/default/QGIS/QGIS3.ini

WORKDIR /config
