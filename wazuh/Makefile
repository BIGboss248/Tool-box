

include ../Makefile

wazuh: docker
	sudo sysctl -w vm.max_map_count=262144
	code .env
	echo "Wazuh environment variables set in .env file set all and whey done press enter to continue"
	@read answer; \
	sudo docker compose -f generate-indexer-certs.yml run --rm generator
	sudo docker compose up --remove-orphans --force-recreate -d
	echo "Visit wazuh dashboard at https://localhost:5601 It may take a few minutes to start up"

wazuh-clean:
	echo "Are you sure you want to remove all Wazuh containers and volumes? [y/N]"
	@read answer; \
	if [ "$$answer" != "y" ] && [ "$$answer" != "Y" ]; then \
		echo "Aborting..."; \
		exit 1; \
	fi
	sudo docker compose down
	sudo docker volume rm wazuh_wazuh_api_configuration wazuh_wazuh_etc wazuh_wazuh_logs wazuh_wazuh_queue wazuh_wazuh_var_multigroups wazuh_wazuh_integrations wazuh_wazuh_active_response wazuh_wazuh_agentless wazuh_wazuh_wodles wazuh_filebeat_etc wazuh_filebeat_var wazuh_wazuh-indexer-data wazuh_wazuh-dashboard-config wazuh_wazuh-dashboard-custom
	sudo rm -rf ./config/wazuh_indexer_ssl_certs
