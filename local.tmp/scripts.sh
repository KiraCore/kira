# Validator vs Sentry

docker build -t validator-test ./validator-test
docker build -t sentry-test ./sentry-test

docker container stop validator
docker container rm validator

docker container stop sentry
docker container rm sentry

docker network rm kiranet || echo "Failed to remove kira network"
docker network rm sentrynet || echo "Failed to remove sentry network"

docker network create --driver=bridge --subnet=10.2.0.0/16 kiranet
docker network create --driver=bridge --subnet=10.3.0.0/16 sentrynet

docker run -d -P --restart=always --name validator --net=kiranet --ip 10.2.0.2 validator-test
docker run -d -P --restart=always --name sentry --net=sentrynet --ip 10.3.0.2 sentry-test

docker network connect kiranet sentry
# docker network connect sentrynet validator
# Validator vs KMS

docker build -t validator-test-0 ./validator-test
docker build -t kms-test ./kms-test

docker container stop validator
docker container rm validator

docker container stop kms
docker container rm kms

docker network rm kiranet || echo "Failed to remove kira network"
docker network rm kmsnet || echo "Failed to remove kira network"

docker network create --driver=bridge --subnet=10.2.0.0/16 kiranet
docker network create --driver=bridge --subnet=10.1.0.0/16 kmsnet

docker run -d -P --restart=always --name validator --net=kiranet --ip 10.2.0.2 validator-test-0
docker run -d -P --restart=always --name kms --net=kmsnet --ip 10.1.0.2 kms-test

docker network connect kiranet kms
docker network connect kmsnet validator

# Frontend installation

docker build -t frontend-test ./frontend-test
docker container stop frontend
docker container rm frontend

docker network rm servicenet || echo "Failed to remove servicenet network"
docker network create --driver=bridge --subnet=10.4.0.0/16 servicenet
docker run -d -p 80:80 --restart=always --name frontend --net=servicenet --ip 10.4.0.3 frontend-test
