if [ -z "${POSTGRES_PASSWORD}" ]
then
	echo "Please set \$POSTGRES_PASSWORD"
	exit 1
fi

if [ -z "${POSTGRES_USER}" ]
then
	POSTGRES_USER=sentry
fi

# Create Docker container (image?).
make build

# Create Docker bridge network to use.
docker network create sentry-network

docker volume create sentry-postgres
docker volume create sentry-data

# Create dependant services for Sentry.
docker run \
   --detach \
   --network sentry-network \
   --mount source=sentry-postgres,target=/var/lib/postgresql/data \
   --env POSTGRES_PASSWORD=${POSTGRES_PASSWORD} \
   --env POSTGRES_USER=${POSTGRES_USER} \
   --name sentry-postgres \
   postgres:9.5

docker run \
   --detach \
   --network sentry-network \
   --name sentry-redis \
   redis:3.2-alpine

docker run \
   --detach \
   --env POSTFIX_myhostname=sentry.affinitybridge.com \
   --network sentry-network \
   --name sentry-smtp \
   mwader/postfix-relay

# Pause to let services start.
echo "Waiting 5 seconds for Postgres to start..."
sleep 5

SENTRY_ENV="\
   --env SENTRY_REDIS_HOST=sentry-redis \
   --env SENTRY_POSTGRES_HOST=sentry-postgres \
   --env SENTRY_DB_USER=${POSTGRES_USER} \
   --env SENTRY_DB_PASSWORD=${POSTGRES_PASSWORD} \
   --env SENTRY_SERVER_EMAIL=sentry@sentry.affinitybridge.com \
   --env SENTRY_EMAIL_HOST=sentry-smtp \
   --env SENTRY_ENABLE_EMAIL_REPLIES=1 \
   --env SENTRY_SMTP_HOSTNAME=sentry.affinitybridge.com \
   --env SENTRY_AUTH_REGISTER=0 \
   --env SENTRY_SINGLE_ORGANIZATION=1 \
   --env SENTRY_USE_SSL=1 \
   --env SENTRY_SECRET_KEY=${SENTRY_SECRET_KEY} \
"

# Start Sentry services.
docker run \
   --network sentry-network \
   ${SENTRY_ENV} \
   --rm \
   -it \
   ${REPOSITORY} \
   upgrade

docker run \
   --detach \
   --network sentry-network \
   --mount source=sentry-data,target=/var/lib/sentry/files \
   ${SENTRY_ENV} \
   --publish 9000:9000 \
   --name sentry-web-01 \
   ${REPOSITORY} \
   run web

docker run \
   --detach \
   --network sentry-network \
   --mount source=sentry-data,target=/var/lib/sentry/files \
   ${SENTRY_ENV} \
   --name sentry-worker-01 \
   ${REPOSITORY} \
   run worker

docker run \
   --detach \
   --network sentry-network \
   --mount source=sentry-data,target=/var/lib/sentry/files \
   ${SENTRY_ENV} \
   --name sentry-cron \
   ${REPOSITORY} \
   run cron

# List Docker Volumes.
docker volume ls
# List Docker networks.
docker network ls
# List running Docker processes.
docker ps -a

# Stop it all now that it's running in favour of the systemd scripts
echo "Stopping Sentry, you can now start by running:\nsystemctl start sentry.target"
docker stop sentry-web-01 sentry-worker-01 sentry-cron sentry-smtp sentry-redis sentry-postgres
docker ps -a
