# kics-scan disable=ae5b6871-7f45-42e0-bb4c-ab300c4d2026
FROM alpine:3.20.3 AS init
# ENV IVENTOY=1.0.20
ARG IVENTOY=1.0.20
WORKDIR /iventoy
RUN echo ${IVENTOY} && \
    wget --progress=dot:giga https://github.com/ventoy/PXE/releases/download/v${IVENTOY}/iventoy-${IVENTOY}-linux-free.tar.gz --max-redirect=0 && \
    tar -xvf ./*.tar.gz && \
    rm -rf iventoy-${IVENTOY}-linux.tar.gz && \
    mv iventoy-${IVENTOY} iventoy
FROM ubuntu:22.04
USER nonroot
ENV AUTO_START_PXE=true
WORKDIR /app
# Copy iventoy
COPY --from=init /iventoy/iventoy /app
RUN chmod +x /app/iventoy.sh

COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Webui
EXPOSE 26000/tcp
# HTTP server
EXPOSE 16000/tcp
HEALTHCHECK --interval=30s --timeout=30s --start-period=30s --retries=3 CMD [ "./iventoy.sh -R start || exit 1" ]
CMD [ "/entrypoint.sh" ]
