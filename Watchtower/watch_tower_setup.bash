#!/bin/bash
sudo bash ./../docker/docker_setup_v2.bash
docker run --detach \
    --name watchtower \
    --volume /var/run/docker.sock:/var/run/docker.sock \
    containrrr/watchtower
