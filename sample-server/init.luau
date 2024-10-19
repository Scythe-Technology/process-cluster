--!strict
local net = require("@zcore/net");
local task = require("@zcore/task");

print("Starting server...");
local throughput = 0;
local ok, server = net.serve({
    port = 8080,
    reuseAddress = true,
    request = function(req)
        throughput += 1;
        return {
            statusCode = 200,
            headers = {
                ["Content-Type"] = "text/plain",
            },
            body = "Hello, World!",
        }
    end
})
assert(ok, server);
assert(type(server) ~= "string", server);

while true do
    task.wait(10);
    print(`Handled Requests: {throughput}`);
    throughput = 0;
end
