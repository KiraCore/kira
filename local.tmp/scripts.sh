docker build -t validator-test-0 ../validator-test
docker build -t kms-test .

docker network rm kiranet || echo "Failed to remove kira network"
docker network create --driver=bridge --subnet=10.2.0.0/16 kiranet

docker network rm kmsnet || echo "Failed to remove kira network"
docker network create --driver=bridge --subnet=10.1.0.0/16 kmsnet

docker run -d --restart=always --name validator --net=kiranet --ip 10.2.0.2 validator-test-0
docker run -d --restart=always --name kms --net=kmsnet --ip 10.1.0.2 kms-test

docker network connect kiranet kms
docker network connect kmsnet validator
