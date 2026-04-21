#!/bin/bash -e
# Custom start.sh for Plane AIO with external MinIO URL support

print_header(){
    clear
    echo "------------------------------------------------"
    echo "Plane Community (All-In-One) - Custom Config"
    echo "------------------------------------------------"
    echo ""
    echo "Required environment variables:"
    echo "    DOMAIN_NAME, DATABASE_URL, REDIS_URL, AMQP_URL"
    echo "    AWS_REGION, AWS_ACCESS_KEY_ID"
    echo "    AWS_SECRET_ACCESS_KEY, AWS_S3_BUCKET_NAME"
    echo ""
}

check_required_env(){
    echo "Checking required environment variables..."
    local keys=("DOMAIN_NAME" "DATABASE_URL" "REDIS_URL" "AMQP_URL" 
                "AWS_REGION" "AWS_ACCESS_KEY_ID" "AWS_SECRET_ACCESS_KEY" "AWS_S3_BUCKET_NAME")
    
    local missing_keys=()
    for key in "${keys[@]}"; do
        if [ -z "${!key}" ]; then
            echo "  ❌  '$key' is not set"
            missing_keys+=("$key")
        fi
    done

    if [ ${#missing_keys[@]} -gt 0 ]; then
        exit 1
    fi
    echo "✅ Required environment variables are available"
    echo ""
}

update_env_value(){
    local key="$1"
    local value="$2"

    if [ ! -f "plane.env" ]; then
        echo "plane.env file not found"
        exit 1
    fi

    if ! grep -q "^$key=.*" plane.env; then
        echo "${key}=${value}" >> plane.env
        return 0
    fi

    if [ -n "$key" ] && [ -n "$value" ]; then
        sed -i "s|^$key=.*|$key=$value|" plane.env
        return 0
    fi
}

validate_domain_name() {
    local domain="$1"
    
    if [[ "$domain" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "IP"
        return 0
    fi
    
    local fqdn_regex='^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*\.?$'
    
    if [[ "$domain" =~ $fqdn_regex ]]; then
        if [[ "$domain" =~ \. ]]; then
            echo "FQDN"
            return 0
        fi
    fi
    
    echo "INVALID"
    return 1
}

update_env_file(){
    echo "Updating environment file..."
    local domain_type=$(validate_domain_name "$DOMAIN_NAME")
    if [ "$domain_type" == "INVALID" ]; then
        echo "DOMAIN_NAME is not valid"
        exit 1
    fi

    local app_protocol=${APP_PROTOCOL:-http}
    
    update_env_value "APP_PROTOCOL" "$app_protocol"
    update_env_value "DOMAIN_NAME" "$DOMAIN_NAME"
    update_env_value "APP_DOMAIN" "$DOMAIN_NAME"
    if [ -n "$SITE_ADDRESS" ]; then
        update_env_value "SITE_ADDRESS" "$SITE_ADDRESS"
    else
        update_env_value "SITE_ADDRESS" ":80"
    fi
    update_env_value "WEB_URL" "$app_protocol://$DOMAIN_NAME"
    update_env_value "CORS_ALLOWED_ORIGINS" "http://$DOMAIN_NAME,https://$DOMAIN_NAME"

    update_env_value "DATABASE_URL" "$DATABASE_URL"
    update_env_value "REDIS_URL" "$REDIS_URL"
    update_env_value "AMQP_URL" "$AMQP_URL"
    
    update_env_value "AWS_REGION" "$AWS_REGION"
    update_env_value "AWS_ACCESS_KEY_ID" "$AWS_ACCESS_KEY_ID"
    update_env_value "AWS_SECRET_ACCESS_KEY" "$AWS_SECRET_ACCESS_KEY"
    update_env_value "AWS_S3_BUCKET_NAME" "$AWS_S3_BUCKET_NAME"
    
    # KEY FIX: Use external MinIO URL for presigned URLs
    # Both API and browser will use plane-minio.lab
    if [ -n "$AWS_S3_EXTERNAL_URL" ]; then
        update_env_value "AWS_S3_ENDPOINT_URL" "$AWS_S3_EXTERNAL_URL"
    else
        update_env_value "AWS_S3_ENDPOINT_URL" "${AWS_S3_ENDPOINT_URL:-https://s3.${AWS_REGION}.amazonaws.com}"
    fi
    
    update_env_value "BUCKET_NAME" "$AWS_S3_BUCKET_NAME"
    update_env_value "USE_MINIO" "0"

    update_env_value "SECRET_KEY" "${SECRET_KEY:-60gp0byfz2dvffa45cxl20p1scy9xbpf6d8c5y0geejgkyp1b5}"
    update_env_value "FILE_SIZE_LIMIT" "${FILE_SIZE_LIMIT:-5242880}"
    update_env_value "LIVE_SERVER_SECRET_KEY" "${LIVE_SERVER_SECRET_KEY:-htbqvBJAgpm9bzvf3r4urJer0ENReatceh}"
    update_env_value "API_KEY_RATE_LIMIT" "${API_KEY_RATE_LIMIT:-60/minute}"

    echo "✅ Environment file updated"
    echo ""
}

main(){
    print_header
    check_required_env
    update_env_file

    export $(grep -v '^#' plane.env | xargs)
    /usr/local/bin/supervisord -c /etc/supervisor/conf.d/supervisor.conf
}

main "$@"
