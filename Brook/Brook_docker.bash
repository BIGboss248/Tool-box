#!/bin/bash

# Set the port number from the first command-line argument, or use a default
#!/bin/bash
BROOK_PORT=${1:-11543}
BROOK_PASS=${2:-password0}
sudo docker run -d \
	-p "$BROOK_PORT":"$BROOK_PORT" \
	-p "$BROOK_PORT":"$BROOK_PORT"/udp \
	--name brook \
	--restart=always \
	-e "ARGS=server -l :$BROOK_PORT -p $BROOK_PASS" \
	teddysun/brook
