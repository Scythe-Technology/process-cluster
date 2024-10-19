# process-cluster

A simple process manager written in luau for Zune.

(WIP)

## Example

The `sample-server` directory contains a simple server that listens on port 8080.
The cluster manager would spawn many servers to run as a cluster.

#### Configuration Example
```toml
[cluster]
workers = 8
type = "server"
boot = "./sample-server"

[backend]
runner = "zune"
args = [ "run", "init.luau" ]
```