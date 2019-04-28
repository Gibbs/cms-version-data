Redirect JSON output;

```
data=$(perl versions.pl --json) && echo "$data" > /tmp/versions.json
```

View JSON output with jq;

```
perl versions.pl --json | jq
```

Update (no output);

```
perl versions.pl
```
