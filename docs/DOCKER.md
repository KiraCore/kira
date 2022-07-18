# Query Address Book

```
docker exec -i seed cat "$SEKAID_HOME/config/addrbook.json"

docker exec -i sentry cat "$SEKAID_HOME/config/addrbook.json"

docker exec -i validator cat "$SEKAID_HOME/config/addrbook.json"
```


# Launch or Open Test Container
```
# To delete all containers & images run:
docker rm -f $(docker ps -a -q) && \
 docker image prune -a -f

# To launch test container run
BASE_NAME="test_container" && \
 BASE_IMG="ghcr.io/kiracore/docker/base-image:v0.11.2" && \
 docker run -i -t -d --privileged --net bridge --name $BASE_NAME --hostname test_container.local $BASE_IMG /bin/bash 

# Find container by name
id=$(timeout 3 docker ps --no-trunc -aqf "name=^${BASE_NAME}$" 2> /dev/null || echo -n "")

# To start existing container
docker start -i $id

# Delete specific container
docker rm -f $id
```