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

# Start dependant services for Sentry.
docker start \
    sentry-postgres \
    sentry-redis \
    sentry-smtp

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

docker stop \
   sentry-web-01 \
   sentry-worker-01 \
   sentry-cron

docker rm sentry-web-01 sentry-worker-01 sentry-cron

docker run \
   --detach \
   --network sentry-network \
   ${SENTRY_ENV} \
   --publish 9000:9000 \
   --name sentry-web-01 \
   ${REPOSITORY} \
   run web

docker run \
   --detach \
   --network sentry-network \
   ${SENTRY_ENV} \
   --name sentry-worker-01 \
   ${REPOSITORY} \
   run worker

docker run \
   --detach \
   --network sentry-network \
   ${SENTRY_ENV} \
   --name sentry-cron \
   ${REPOSITORY} \
   run cron

docker start sentry-web-01 sentry-worker-01 sentry-cron

# List Docker networks.
docker network ls
# List running Docker processes.
docker ps -a
