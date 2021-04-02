## Show Token Aliases

```
sekaid query tokens all-aliases --output=json | jq
```

## Show Network Props

```
sekaid query customgov network-properties --output=json | jq
```

## Show List Of Validator

```
echo $(curl 0.0.0.0:$KIRA_INTERX_PORT/api/valopers?all=true | jq)
```
