

include ../Makefile

wazuh: docker
	sudo sysctl -w vm.max_map_count=262144
	echo "Change password for dashboard and API users by follow this guide:"
	echo "https://documentation.wazuh.com/current/deployment-options/docker/wazuh-container.html#change-the-password-of-wazuh-users"
	sudo docker run --user root -v ./config/wazuh_indexer_ssl_certs/:/certificates/ -v ./config/certs.yml:/config/certs.yml  wazuh/wazuh-certs-generator:0.0.2
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

wazuh-change-pass:
	sudo docker-compose down
	echo "Enter the new password and copy the generated hash Don't use the $ or & characters in your new password.Press enter to continue"
	sudo docker run --rm -ti wazuh/wazuh-indexer:4.12.0 bash /usr/share/wazuh-indexer/plugins/opensearch-security/tools/hash.sh
	read answer
	echo "Update the hash attribute of the user you want to change the password press enter to continue"
	code ./config/wazuh_indexer/internal_users.yml
	read answer
	echo "update all ocurrences of the password in docker-compose.yml press enter to continue"
	code ./docker-compose.yml
	read answer
	sudo docker-compose up -d
	docker exec -it wazuh.indexer export INSTALLATION_DIR=/usr/share/wazuh-indexer
	docker exec -it wazuh.indexer export CACERT=$INSTALLATION_DIR/certs/root-ca.pem
	docker exec -it wazuh.indexer export KEY=$INSTALLATION_DIR/certs/admin-key.pem
	docker exec -it wazuh.indexer export CERT=$INSTALLATION_DIR/certs/admin.pem
	docker exec -it wazuh.indexer export JAVA_HOME=/usr/share/wazuh-indexer/jdk
	docker exec -it wazuh.indexer bash /usr/share/wazuh-indexer/plugins/opensearch-security/tools/securityadmin.sh -cd /usr/share/wazuh-indexer/opensearch-security/ -nhnv -cacert  $CACERT -cert $CERT -key $KEY -p 9200 -icl

wazuh-api-change-password:
	echo "Change the password attribute"
	code ./config/wazuh_dashboard/wazuh.yml
	echo "Change the password attribute"
	code ./docker-compose.yml
	sudo docker-compose down
	sudo docker-compose up -d
