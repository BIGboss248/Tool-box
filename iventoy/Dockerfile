FROM alpine as init
# ENV IVENTOY=1.0.20
ARG IVENTOY=1.0.20
WORKDIR /iventoy
RUN echo ${IVENTOY} && \
    wget https://github.com/ventoy/PXE/releases/download/v${IVENTOY}/iventoy-${IVENTOY}-linux-free.tar.gz && \
    tar -xvf *.tar.gz && \
    rm -rf iventoy-${IVENTOY}-linux.tar.gz && \
    mv iventoy-${IVENTOY} iventoy
FROM ubuntu
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
CMD /entrypoint.sh
