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
# echo $(globGet BASE_IMAGE_SRC)

BASE_NAME="test" && \
 BASE_IMG="ghcr.io/kiracore/docker/kira-base:v0.11.4" && \
 docker run -i -t -d --privileged --net bridge --name $BASE_NAME --hostname test.local $BASE_IMG /bin/bash

# Find container by name
id=$(timeout 3 docker ps --no-trunc -aqf "name=^${BASE_NAME}$" 2> /dev/null || echo -n "")

# To start existing container
# one liner: docker start -i $(timeout 3 docker ps --no-trunc -aqf "name=^${BASE_NAME}$" 2> /dev/null || echo -n "")
docker start -i $id

# Delete specific container
# one liner: docker rm -f $(timeout 3 docker ps --no-trunc -aqf "name=^${BASE_NAME}$" 2> /dev/null || echo -n "")
docker rm -f $id
```