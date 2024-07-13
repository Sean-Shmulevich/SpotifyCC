-- Taskmaster: A simple and highly flexible task runner/coroutine manager for ComputerCraft
-- Supports adding/removing tasks, early exits for tasks, event white/blacklists, automatic
-- terminal redirection, task pausing, promises, and more.
-- Made by JackMacWindows
-- Licensed under CC0 in the public domain

--[[
    Examples:

    - Run three functions in parallel, and wait for any to exit.

        require("taskmaster")(
            func1, func2, func3
        ):waitForAny()
    
    - Run three functions in parallel, and wait for all to exit.

        require("taskmaster")(
            func1, func2, func3
        ):waitForAll()

    - Builder-style creation of three event listeners for keyboard events.

        require("taskmaster")()
            :eventListener("key", function(ev, key) print("Key:", keys.getName(key)) end)
            :eventListener("key_up", function(ev, key) print("Key up:", keys.getName(key)) end)
            :eventListener("char", function(ev, char) print("Character:", char) end)
            :run()

    - Create a loop with two background tasks (which don't receive user interaction events) and one foreground task.
      The foreground task may exit itself if a specific character is pressed.

        local loop = require("taskmaster")()
        loop:setEventBlacklist {"key", "key_up", "char", "paste", "mouse_click", "mouse_up", "mouse_scroll", "mouse_drag"}
        loop:addTask(bgFunc)
        loop:addTimer(2, pollingFunction)

        local function fgFunc(task)
            while true do
                local event, p1 = os.pullEvent()
                if event == "char" and p1 == "q" then
                    task:remove()
                end
            end
        end

        local task = loop:addTask(fgFunc)
        task:setEventBlacklist {}
        task:setPriority(10)

        loop:run()
    
    - Fetch a remote JSON resource in parallel using promises.

        local loop = require("taskmaster")()

        local function main()
            loop.Promise.fetch("https://httpbin.org/headers")
                :next(function(handle) return handle.json() end)
                :next(function(data) print(data.headers["User-Agent"]) end)
                :catch(printError)
        end

        loop:task(main):run()
]]

local expect = require "cc.expect"

---@class Task
---@field master Taskmaster The event loop for the task
local Task = {}
local Task_mt = {__name = "Task", __index = Task}

--- Pauses the task, preventing it from running. This will yield if the task calls this method on itself.
function Task:pause()
    self.paused = true
    if self.master.currentTask == self then coroutine.yield() end
end

--- Unpauses the task if it was previously paused by @{Task.pause}.
function Task:unpause()
    self.paused = false
end

--- Removes the task from the run loop, as if it returned. This will yield if the task calls this method on itself.
function Task:remove()
    self.master.dead[#self.master.dead+1] = self
    if self.master.currentTask == self then coroutine.yield() end
end

--- Sets the priority of the task. This determines the order tasks are run in.
---@param priority number The priority of the task (0 is the default)
function Task:setPriority(priority)
    expect(1, priority, "number")
    self.priority = priority
    self.master.shouldSort = true
end

--- Sets a blacklist for events to send to this task.
---@param list? string[] A list of events to not send to this task
function Task:setEventBlacklist(list)
    if expect(1, list, "table", "nil") then
        self.blacklist = {}
        for _, v in ipairs(list) do self.blacklist[v] = true end
    else self.blacklist = nil end
end

--- Sets a whitelist for events to send to this task.
---@param list? string[] A list of events to send to this task (others are discarded)
function Task:setEventWhitelist(list)
    if expect(1, list, "table", "nil") then
        self.whitelist = {}
        for _, v in ipairs(list) do self.whitelist[v] = true end
    else self.whitelist = nil end
end

---@class Promise
---@field private task Task
---@field private resolve fun(...: any)|nil
---@field private reject fun(err: any)|nil
---@field private final fun()|nil
local Promise = {}
local Promise_mt = {__name = "Promise", __index = Promise}

--- Creates a new Promise on the selected run loop.
---@param loop Taskmaster The loop to create the promise on
---@param fn fun(resolve: fun(...: any), reject: fun(err: any)) The main function for the promise
---@return Promise promise The new promise
function Promise:new(loop, fn)
    expect(1, loop, "table")
    expect(2, fn, "function")
    local obj = setmetatable({}, Promise_mt)
    obj.task = loop:addTask(function()
        local ok, err = pcall(fn,
            function(...) if obj.resolve then return obj.resolve(...) end end,
            function(err)
                while obj do
                    if obj.reject then return obj.reject(err) end
                    obj = obj.next_promise
                end
            end
        )
        if not ok and obj.reject then obj.reject(err) end
    end)
    return obj
end

--- Creates a new Promise that resolves once all of the listed promises resolve.
---@param loop Taskmaster The loop to create the promise on
---@param list Promise[] The promises to wait for
---@return Promise promise The new promise
function Promise:all(loop, list)
    expect(1, loop, "table")
    expect(2, list, "table")
    return Promise:new(loop, function(resolve, reject)
        local count = 0
        for _, v in ipairs(list) do
            v:next(function(...)
                count = count + 1
                if count == #list then resolve(...) end
            end, reject)
        end
    end)
end

--- Creates a new Promise that resolves once any of the listed promises resolve, or rejects if all promises reject.
---@param loop Taskmaster The loop to create the promise on
---@param list Promise[] The promises to wait for
---@return Promise promise The new promise
function Promise:any(loop, list)
    expect(1, loop, "table")
    expect(2, list, "table")
    return Promise:new(loop, function(resolve, reject)
        local count = 0
        for _, v in ipairs(list) do
            v:next(resolve, function(err)
                count = count + 1
                if count == #list then reject(err) end
            end)
        end
    end)
end

--- Creates a new Promise that resolves once any of the listed promises resolve.
---@param loop Taskmaster The loop to create the promise on
---@param list Promise[] The promises to wait for
---@return Promise promise The new promise
function Promise:race(loop, list)
    expect(1, loop, "table")
    expect(2, list, "table")
    return Promise:new(loop, function(resolve, reject)
        for _, v in ipairs(list) do v:next(resolve, reject) end
    end)
end

--- Creates a new Promise that immediately resolves to a value.
---@param loop Taskmaster The loop to create the promise on
---@param val any The value to resolve to
---@return Promise promise The new promise
function Promise:_resolve(loop, val)
    expect(1, loop, "table")
    local obj = setmetatable({}, Promise_mt)
    obj.task = loop:addTask(function()
        if obj.resolve then obj.resolve(val) end
    end)
    return obj
end

--- Creates a new Promise that immediately rejects with an error.
---@param loop Taskmaster The loop to create the promise on
---@param err any The value to resolve to
---@return Promise promise The new promise
function Promise:_reject(loop, err)
    expect(1, loop, "table")
    local obj = setmetatable({}, Promise_mt)
    obj.task = loop:addTask(function()
        if obj.reject then obj.reject(err) end
    end)
    return obj
end

--- Adds a function to call when the promise resolves.
---@param fn fun(...: any): Promise|nil The function to call
---@param err? fun(err: any) A function to catch errors
---@return Promise next The next promise in the chain
function Promise:next(fn, err)
    expect(1, fn, "function")
    expect(2, err, "function", "nil")
    self.resolve = function(...)
        self.resolve = nil
        local res = fn(...)
        if self.next_promise then
            if type(res) == "table" and getmetatable(res) == Promise_mt then
                for k, v in pairs(self.next_promise) do res[k] = v end
                self.next_promise = res
            else
                self.next_promise.resolve(res)
            end
        end
        if self.final then self.final() end
    end
    if err then self.reject = function(v) self.reject = nil err(v) if self.final then self.final() end end end
    self.next_promise = setmetatable({}, Promise_mt)
    return self.next_promise
end
Promise.Then = Promise.next

--- Sets the error handler for the promise.
---@param fn fun(err: any) The error handler to use
---@return Promise self
function Promise:catch(fn)
    expect(1, fn, "function")
    self.reject = function(err) self.reject = nil fn(err) if self.final then self.final() end end
    return self
end

--- Sets a function to call after the promise settles.
---@param fn fun() The function to call
---@return Promise self
function Promise:finally(fn)
    expect(1, fn, "function")
    self.final = function() self.final = nil return fn() end
    return self
end

---@diagnostic disable: missing-return

---@class PromiseConstructor
local PromiseConstructor = {}

--- Creates a new Promise on the selected run loop.
---@param fn fun(resolve: fun(...: any), reject: fun(err: any)) The main function for the promise
---@return Promise promise The new promise
function PromiseConstructor.new(fn) end

--- Creates a new Promise that resolves once all of the listed promises resolve.
---@param list Promise[] The promises to wait for
---@return Promise promise The new promise
function PromiseConstructor.all(list) end

--- Creates a new Promise that resolves once any of the listed promises resolve, or rejects if all promises reject.
---@param list Promise[] The promises to wait for
---@return Promise promise The new promise
function PromiseConstructor.any(list) end

--- Creates a new Promise that resolves once any of the listed promises resolve.
---@param list Promise[] The promises to wait for
---@return Promise promise The new promise
function PromiseConstructor.race(list) end

--- Creates a new Promise that immediately resolves to a value.
---@param val any The value to resolve to
---@return Promise promise The new promise
function PromiseConstructor.resolve(val) end

--- Creates a new Promise that immediately rejects with an error.
---@param err any The value to resolve to
---@return Promise promise The new promise
function PromiseConstructor.reject(err) end

--- Makes an HTTP request to a URL, and returns a Promise for the result.
--- The promise will resolve with the handle to the response, which will also
--- have the following methods:
--- - res.text(): Returns a promise that resolves to the body of the response.
--- - res.table(): Returns a promise that resolves to the body unserialized as a Lua table.
--- - res.json(): Returns a promise that resolves to the body unserialized as JSON.
---@param url string The URL to connect to
---@param body? string If specified, a POST body to send
---@param headers? table<string, string> Any HTTP headers to add to the request
---@param binary? boolean Whether to send in binary mode (deprecated as of CC:T 1.109.0)
---@overload fun(options: {url: string, body?: string, headers?: string, method?: string, binary?: string, timeout?: number}): Promise
---@return Promise promise The new promise
function PromiseConstructor.fetch(url, body, headers, binary) end

---@diagnostic enable: missing-return

---@class Taskmaster
---@field Promise PromiseConstructor
local Taskmaster = {}
local Taskmaster_mt = {__name = "Taskmaster", __index = Taskmaster}

--- Adds a task to the loop.
---@param fn fun(Task) The main function to add, which receives the task as an argument
---@return Task task The created task
function Taskmaster:addTask(fn)
    expect(1, fn, "function")
    local task = setmetatable({coro = coroutine.create(fn), master = self, priority = 0}, Task_mt)
    self.new[#self.new+1] = task
    self.shouldSort = true
    return task
end

--- Adds a task to the loop in builder style.
---@param fn fun(Task) The main function to add
---@return Taskmaster self
function Taskmaster:task(fn) self:addTask(fn) return self end

--- Adds an event listener to the loop. This is a special task that calls a function whenever an event is triggered.
---@param name string The name of the event to listen for
---@param fn fun(string, ...) The function to call for each event
---@return Task task The created task
function Taskmaster:addEventListener(name, fn)
    expect(1, name, "string")
    expect(2, fn, "function")
    local task = setmetatable({coro = coroutine.create(function() while true do fn(os.pullEvent(name)) end end), master = self, priority = 0}, Task_mt)
    self.new[#self.new+1] = task
    self.shouldSort = true
    return task
end

--- Adds an event listener to the loop in builder style. This is a special task that calls a function whenever an event is triggered.
---@param name string The name of the event to listen for
---@param fn fun(string, ...) The function to call for each event
---@return Taskmaster self
function Taskmaster:eventListener(name, fn) self:addEventListener(name, fn) return self end

--- Adds a task that triggers a function repeatedly after an interval. The function may modify or cancel the interval through a return value.
---@param timeout number The initial interval to run the function after
---@param fn fun():number|nil The function to call.
---If this returns a number, that number replaces the timeout.
---If this returns a number less than or equal to 0, the timer is canceled.
---If this returns nil, the timeout remains the same.
---@return Task task The created task
function Taskmaster:addTimer(timeout, fn)
    expect(1, timeout, "number")
    expect(2, fn, "function")
    local task = setmetatable({coro = coroutine.create(function()
        while true do
            sleep(timeout)
            timeout = fn() or timeout
            if timeout <= 0 then return end
        end
    end), master = self, priority = 0}, Task_mt)
    self.new[#self.new+1] = task
    self.shouldSort = true
    return task
end

--- Adds a task that triggers a function repeatedly after an interval in builder style. The function may modify or cancel the interval through a return value.
---@param timeout number The initial interval to run the function after
---@param fn fun():number|nil The function to call.
---If this returns a number, that number replaces the timeout.
---If this returns a number less than or equal to 0, the timer is canceled.
---If this returns nil, the timeout remains the same.
---@return Taskmaster self
function Taskmaster:timer(timeout, fn) self:addTimer(timeout, fn) return self end

--- Sets a blacklist for events to send to all tasks. Tasks can override this with their own blacklist.
---@param list? string[] A list of events to not send to any task
function Taskmaster:setEventBlacklist(list)
    if expect(1, list, "table", "nil") then
        self.blacklist = {}
        for _, v in ipairs(list) do self.blacklist[v] = true end
    else self.blacklist = nil end
end

--- Sets a whitelist for events to send to all tasks. Tasks can override this with their own whitelist.
---@param list? string[] A list of events to send to all tasks (others are discarded)
function Taskmaster:setEventWhitelist(list)
    if expect(1, list, "table", "nil") then
        self.whitelist = {}
        for _, v in ipairs(list) do self.whitelist[v] = true end
    else self.whitelist = nil end
end

--- Sets a function that is used to transform events. This function takes a task
--- and event table, and may modify the event table to adjust the event for that task.
---@param fn fun(Task, table)|nil A function to use to transform events
function Taskmaster:setEventTransformer(fn)
    expect(1, fn, "function", "nil")
    self.transformer = fn
end

--- Runs the main loop, processing events and running each task.
---@param count? number The number of tasks that can exit before stopping the loop
function Taskmaster:run(count)
    count = expect(1, count, "number", "nil") or math.huge
    self.running = true
    while self.running and (#self.tasks + #self.new) > 0 and count > 0 do
        for i, task in ipairs(self.new) do
            self.currentTask = task
            local old = term.current()
            local ok, filter = coroutine.resume(task.coro, task)
            task.window = term.redirect(old)
            if not ok then
                self.currentTask = nil
                self.running = false
                self.new = {table.unpack(self.new, i + 1)}
                return error(filter, 0)
            end
            task.filter = filter
            if coroutine.status(task.coro) == "dead" then count = count - 1
            else self.tasks[#self.tasks+1], self.shouldSort = task, true end
            if not self.running or count <= 0 then break end
        end
        self.new, self.dead = {}, {}
        if self.shouldSort then table.sort(self.tasks, function(a, b) return a.priority > b.priority end) self.shouldSort = false end
        if self.running and #self.tasks > 0 and count > 0 then
            local _ev = table.pack(os.pullEventRaw())
            for i, task in ipairs(self.tasks) do
                local ev = _ev
                if self.transformer then
                    ev = table.pack(table.unpack(_ev, 1, _ev.n))
                    self.transformer(task, ev)
                end
                local wl, bl = task.whitelist or self.whitelist, task.blacklist or self.blacklist
                if not task.paused and
                    (task.filter == nil or task.filter == ev[1] or ev[1] == "terminate") and
                    (not bl or not bl[ev[1]]) and
                    (not wl or wl[ev[1]]) then
                    self.currentTask = task
                    local old = term.redirect(task.window)
                    local ok, filter = coroutine.resume(task.coro, table.unpack(ev, 1, ev.n))
                    task.window = term.redirect(old)
                    if not ok then
                        self.currentTask = nil
                        self.running = false
                        table.remove(self.tasks, i)
                        return error(filter, 0)
                    end
                    task.filter = filter
                    if coroutine.status(task.coro) == "dead" then self.dead[#self.dead+1] = task end
                    if not self.running or #self.dead >= count then break end
                end
            end
        end
        self.currentTask = nil
        for _, task in ipairs(self.dead) do
            for i, v in ipairs(self.tasks) do
                if v == task then
                    table.remove(self.tasks, i)
                    count = count - 1
                    break
                end
            end
        end
    end
    self.running = false
end

--- Runs all tasks until a single task exits.
function Taskmaster:waitForAny() return self:run(1) end
--- Runs all tasks until all tasks exit.
function Taskmaster:waitForAll() return self:run() end

--- Stops the main loop if it is running. This will yield if called from a running task.
function Taskmaster:stop()
    self.running = false
    if self.currentTask then coroutine.yield() end
end

Taskmaster_mt.__call = Taskmaster.run

local function fetch(loop, url, ...)
    if not http.request(url, ...) then return nil end
    return loop.Promise.new(function(resolve, reject)
        while true do
            local event, p1, p2, p3 = os.pullEvent()
            if event == "http_success" and p1 == url then
                p2.text = function()
                    return loop.Promise.new(function(_resolve, _reject)
                        local data = p2.readAll()
                        p2.close()
                        _resolve(data)
                    end)
                end
                p2.json = function()
                    return loop.Promise.new(function(_resolve, _reject)
                        local data = p2.readAll()
                        p2.close()
                        local d = textutils.unserializeJSON(data)
                        if d ~= nil then _resolve(d)
                        else _reject("Failed to parse JSON") end
                    end)
                end
                p2.table = function()
                    return loop.Promise.new(function(_resolve, _reject)
                        local data = p2.readAll()
                        p2.close()
                        local d = textutils.unserialize(data)
                        if d ~= nil then _resolve(d)
                        else _reject("Failed to parse Lua table") end
                    end)
                end
                return resolve(p2)
            elseif event == "http_failure" and p1 == url then
                if p3 then p3.close() end
                return reject(p2)
            end
        end
    end)
end

--- Creates a new Taskmaster run loop.
---@param ... fun() Any tasks to add to the loop
---@return Taskmaster loop The new Taskmaster
return function(...)
    local loop = setmetatable({tasks = {}, dead = {}, new = {}}, Taskmaster_mt)
    for i, v in ipairs{...} do
        expect(i, v, "function")
        loop:addTask(v)
    end
    loop.Promise = {
        new = function(fn) return Promise:new(loop, fn) end,
        all = function(list) return Promise:all(loop, list) end,
        any = function(list) return Promise:any(loop, list) end,
        race = function(list) return Promise:race(loop, list) end,
        resolve = function(val) return Promise:_resolve(loop, val) end,
        reject = function(err) return Promise:_reject(loop, err) end,
        fetch = function(...) return fetch(loop, ...) end
    }
    setmetatable(loop.Promise, {__call = function(self, ...) return Promise:new(loop, ...) end})
    return loop
end