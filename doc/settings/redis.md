# Redis settings

## Using a non-packaged Redis instance

If you want to use your own Redis instance instead of the bundled Redis, you
can use the `gitlab.rb` settings below. Run `gitlab-ctl reconfigure` for the
settings to take effect.

```ruby
redis['enable'] = false

# Redis via TCP
gitlab_rails['redis_host'] = 'redis.example.com'
gitlab_rails['redis_port'] = 6380

# OR Redis via Unix domain sockets
gitlab_rails['redis_socket'] = '/tmp/redis.sock' # defaults to /var/opt/gitlab/redis/redis.socket
```

## Making a bundled Redis instance reachable via TCP

Use the following settings if you want to make one of the Redis instances
managed by omnibus-gitlab reachable via TCP.

```ruby
redis['port'] = 6379
redis['bind'] = '127.0.0.1'
```

## Tuning the TCP stack for Redis

The following settings are to enable a more performant Redis server instance. 'tcp_timeout' is
a value set in seconds that the Redis server waits before terminating an IDLE TCP connection.
The 'tcp_keepalive' is a tunable setting in seconds to TCP ACKs to clients in absence of 
communication.

```ruby
redis['tcp_timeout'] = "60"
redis['tcp_keepalive'] = "0"
```

