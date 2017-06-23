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

# Create dependant services for Sentry.
docker run \
   --detach \
   --env POSTGRES_PASSWORD=${POSTGRES_PASSWORD} \
   --env POSTGRES_USER=${POSTGRES_USER} \
   --name sentry-postgres \
   postgres:9.5

docker run \
   --detach \
   --name sentry-redis \
   redis:3.2-alpine

docker run \
   --detach \
   --name sentry-smtp \
   tianon/exim4

# Pause to let services start.
echo "Waiting 5 seconds for Postgres to start..."
sleep 5

# Setting some helper variables.
SENTRY_SERVICES="\
   --link sentry-redis:redis \
   --link sentry-postgres:postgres \
   --link sentry-smtp:smtp \
"

SENTRY_ENV="\
   --env SENTRY_SERVER_EMAIL=sentry@sentry.affinitybridge.com \
   --env SENTRY_EMAIL_HOST=localhost \
   --env SENTRY_ENABLE_EMAIL_REPLIES=1 \
   --env SENTRY_SMTP_HOSTNAME=sentry.affinitybridge.com \
   --env SENTRY_AUTH_REGISTER=0 \
   --env SENTRY_SINGLE_ORGANIZATION=1 \
   --env SENTRY_USE_SSL=1 \
   --env SENTRY_SECRET_KEY=${SENTRY_SECRET_KEY} \
"

# Start Sentry services.
docker run \
   ${SENTRY_SERVICES} \
   ${SENTRY_ENV} \
   --rm \
   -it \
   ${REPOSITORY} \
   upgrade

docker run \
   --detach \
   ${SENTRY_SERVICES} \
   ${SENTRY_ENV} \
   --publish 9000:9000 \
   --name sentry-web-01 \
   ${REPOSITORY} \
   run web

docker run \
   --detach \
   ${SENTRY_SERVICES} \
   ${SENTRY_ENV} \
   --name sentry-worker-01 \
   ${REPOSITORY} \
   run worker

docker run \
   --detach \
   ${SENTRY_SERVICES} \
   ${SENTRY_ENV} \
   --name sentry-cron \
   ${REPOSITORY} \
   run cron

# List running Docker processes.
docker ps -a
