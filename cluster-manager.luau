local fs = require("@zcore/fs");
local task = require("@zcore/task");
local stdio = require("@zcore/stdio");
local serde = require("@zcore/serde");
local process = require("@zcore/process");

local _, version, _ = _VERSION:match("(Zune) (%d+%.%d+%.%d+.*)+(%d+%.%d+)");
assert(version and #version > 0, "No version");
local major, minor, patch = version:match("(%d+)%.(%d+)%.(%d+)");
major = assert(tonumber(major), "Invalid major version");
minor = assert(tonumber(minor), "Invalid minor version");
patch = assert(tonumber(patch), "Invalid patch version");

assert(
    major >= 0 and minor >= 4 and patch >= 3,
    "Zune version must be 0.4.3 or higher"
)

local ok, config_file = fs.readFile("config.toml");
assert(ok, "You must have a 'config.toml' file in the root directory of the project");
local config = serde.toml.decode(config_file);

assert(type(config.cluster) == "table", "cluster field must be a table");
assert(type(config.cluster.workers) == "number", "cluster.workers field must be a number");
assert(type(config.cluster.type) == "string", "cluster.type field must be a string");
assert(type(config.cluster.boot) == "string", "cluster.boot field must be a string");

assert(type(config.backend) == "table", "backend field must be a table");
assert(type(config.backend.runner) == "string", "backend.runner field must be a string");
assert(type(config.backend.args) == "table", "backend.args field must be a table");
local args = {};
for _, arg in ipairs(config.backend.args) do
    assert(type(arg) == "string", "backend.args field must be a list of strings");
    table.insert(args, arg);
end

local workers = {};

local function getWorkerId(worker: process.ProcessChild): number?
    return table.find(workers, worker);
end

local function getColor(id: number) : string
    local colors = {
        "red",
        "green",
        "yellow",
        "blue",
        "magenta",
        "cyan",
        "white",
    };
    return colors[id % #colors + 1];
end

local function spawnWorker(count : number)
    print(`Spawning worker ({count})...`);
    local ok, worker = process.create(config.backend.runner, args, {cwd = config.cluster.boot, shell = true});
    assert(ok, worker);
    assert(type(worker) ~= "string");
    table.insert(workers, worker);
    task.spawn(function()
        while not worker.dead do
            local id = getWorkerId(worker);
            local stdErr = worker:readErr();
            if (stdErr) then
                local lines = stdErr:split("\n");
                for i, line in lines do
                    if (#line == 0 and i == #lines) then
                        continue;
                    end
                    stdio.color("red");
                    print(`[{stdio.color(getColor(id)::any)}Worker {id}{stdio.reset("color")}] {line}`);
                end
            end
            task.wait(1);
        end
        local id = getWorkerId(worker);
        print(`Worker {id} unexpected stop.`);
        local ok, err = pcall(function()
            worker:kill();
        end);
        if (not ok) then
            print(`Failed to kill worker {id}: {err}`);
        end
        table.remove(workers, getWorkerId(worker));
    end);
    print(`Worker spawned ({count}).`);
end

local function close()
    print("Killing workers...");
    for i, worker in workers do
        local ok, err = pcall(function()
            worker:kill();
        end);
        if (not ok) then
            print(`Failed to kill worker {i}: {err}`);
            continue;
        end
        print(`Killed worker {i}.`);
    end
    print("Exitting...");
    process.exit(0);
end

process.onSignal("INT", close)

local job_count = 0;
local run_once = config.cluster.type == "once";
while true do
    if (#workers == 0 and job_count >= config.cluster.workers and run_once) then
        break;
    elseif ((#workers < config.cluster.workers and not run_once) or (job_count < config.cluster.workers and run_once)) then
        spawnWorker(job_count);
        job_count += 1;
    end
    task.wait();
end

close();