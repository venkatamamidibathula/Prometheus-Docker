#!/bin/bash

set +ex

get_container_id() {
    local container_name=$1
    docker ps --filter "name=$container_name" --format "{{.ID}}"
}

validate_config() {
    local local_file_path=$1
    local container_file_path=$2
    local image_name=$3
    local config_file=$4
    local port=$5

    if [[ $image_name == "quay.io/prometheusmsteams/prometheus-msteams:v1.5.0" ]]; then

    	docker run --rm -v $(pwd)/$local_file_path:$container_file_path $image_name --config-file=$container_file_path/$config_file --http-addr=":$port" &
	sleep 5
    	docker stop $(docker ps --filter "ancestor=$image_name" --format "{{.ID}}")
    else
    	docker run --rm -v $(pwd)/$local_file_path:$container_file_path $image_name --config.file=$container_file_path/$config_file --web.listen-address=":$port" &
        sleep 5
        docker stop $(docker ps --filter "ancestor=$image_name" --format "{{.ID}}")
    fi

    return $?

}


reload_config() {
    local local_file_path=$1
    local container_id=$2
    local container_path=$3
    if [[ $local_file_path == "msteams" ]];then
	docker-compose stop prommsteams
	docker-compose rm -f prommsteams
	docker-compose build prommsteams
	docker-compose up -d prommsteams
    else
    	docker cp $local_file_path/. $container_id:$container_path
    	docker kill --signal=SIGHUP $container_id
    fi
}

reload_container() {
    local container_name=$1
    local local_file_path=$2
    local container_file_path=$3
    local image_name=$4
    local config_file=$5
    local port=$6

    local container_id=$(get_container_id $container_name)
    if [[ -z $container_id ]]; then
        echo "$container_name container is not running"
	service_name=$(echo "$container_name" | sed 's/^prometheus-//')
	echo "$service_name"
        docker-compose build $service_name
        docker-compose up -d $service_name
    else
        echo "$container_name Container ID: $container_id"
        echo "Validating $container_name configuration..."
        if [[ $container_name == "prometheus-nginx" ]]; then
            docker cp $local_file_path/. $container_id:$container_file_path
            docker exec $container_id nginx -s reload
        elif [[ $container_name == "prometheus-grafana" ]]; then
            echo "$container_name container is already running and we are not reloading..."
        else
            validate_config $local_file_path $container_file_path $image_name $config_file $port
            if [[ $? -eq 0 ]]; then
		    	if [[ ${branch_name} == develop ]];then
                	echo "$container_name configuration is valid. Reloading..."
                	reload_config $local_file_path $container_id $container_file_path
                	echo "$container_name configuration reloaded successfully..."
		    	else
					echo "$container_name configuration is valid for ${branch_name}" 
					echo "Branch is not develop and SIGHUP reload is not permitted for ${branch_name}"
		    	fi
	    	else
                echo "$container_name configuration is invalid..."
				exit 1
            fi
        fi
    fi
}

reload_prometheus() {
    echo "Prometheus configurations SIGHUP happens only for ${branch_name}"
    reload_container "prometheus-grafana" "grafana/grafana.ini" "/etc/grafana/grafana.ini" "grafana/grafana:latest" "grafana.ini" "3000"
    reload_container "prometheus-blackboxexporter" "blackbox_exporter" "/etc/blackbox-exporter" "prom/blackbox-exporter:latest" "blackbox.yml" "9116"
    reload_container "prometheus-prometheus" "prometheus" "/etc/prometheus" "prom/prometheus:latest" "prometheus.yml" "9090"
    reload_container "prometheus-alertmanager" "alertmanager" "/etc/alertmanager" "prom/alertmanager:latest" "alertmanager.yml" "9093"
    reload_container "prometheus-nginx" "nginx" "/etc/nginx" "nginx:latest" "nginx.conf" "443"
    reload_container "prometheus-prommsteams" "msteams" "/etc/prometheus-msteams" "quay.io/prometheusmsteams/prometheus-msteams:v1.5.0" "config.yml" "2000"

}
branch_name=$1
reload_prometheus
