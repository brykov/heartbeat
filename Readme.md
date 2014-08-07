Heartbeat service
=================

This is a basic HTTP service built on top of Goliath and Grape.

The server can be started as following:

```
bundle exec ruby server.rb -sv
```

After the launch it will start listening ```http://localhost:9000``` and responding to similar requests:

```
curl -v -H Content-Type:application/json http://localhost:9000/v1/heartbeat/throughput

curl -v -X POST -d '{"app_id":"app1","customer_id":"customer1","video_id":"video1"}' -H Content-Type:application/json http://localhost:9000/v1/heartbeat/ping

curl -v -H Content-Type:application/json "http://localhost:9000/v1/heartbeat/number_of_videos?app_id=app1&customer_id=customer1"

curl -v -H Content-Type:application/json "http://localhost:9000/v1/heartbeat/number_of_viwers?app_id=app1&video_id=video1"

```

The server supports different implementations. It comes with 2 implementations on board: ```HeartbeatBasicHashes``` (default one) and ```HeartbeatOOP```.

  
In order to switch implementation an environment variable may be used:
  
```
IMPLEMENTATION=HeartbeatOOP bundle exec ruby server.rb -sv
```

Two other environment variables are also supported: ```VIDEO_ONLINE_TTL_SECONDS``` and ```STALE_DATA_TTL_SECONDS```.

Testing
-------

Run rspec tests as following:

```
bundle exec rspec spec.rb

IMPLEMENTATION=HeartbeatOOP bundle exec rspec spec.rb
```
