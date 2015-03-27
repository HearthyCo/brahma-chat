export DB_USER='brahma'
export DB_PASS='Better_to_conquer_yourself_than_others_'
export DATABASE_URL="postgres://${DB_USER}:${DB_PASS}@${POSTGRES_PORT:6}/brahma?stringtype=unspecified"
export DB_URL="jdbc:postgresql://${POSTGRES_PORT:6}/brahma?stringtype=unspecified"
export AMQP_URI="amqp://guest:guest@${AMQP_PORT:6}"
export REDIS_URL="$REDIS_PORT"
export IAM='brahma-api-dev'
