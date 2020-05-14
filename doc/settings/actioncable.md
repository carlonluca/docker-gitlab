# ActionCable

ActionCable is run as a separate Puma server that only handles websocket connections.

NOTE: **Note:** ActionCable is **experimental** and the features that use this service are behind feature flags.

This service is disabled by default. To enable:

```ruby
actioncable['enable'] = true
```

## Configuring the worker pool size

ActionCable uses a separate thread pool to handle the websocket connections. The number of threads can be configured
using the `actioncable['worker_pool_size']` option.
