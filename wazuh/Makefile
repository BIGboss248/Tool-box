

include ../Makefile

wazuh: docker
	sudo sysctl -w vm.max_map_count=262144
	sudo docker compose -f generate-indexer-certs.yml run --rm generator
	sudo docker compose up -d
	echo "Visit wazuh dashboard at https://localhost:5601"
