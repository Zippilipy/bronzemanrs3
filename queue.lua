-- AI generated
local Queue = {}
Queue.__index = Queue

function Queue.new()
    return setmetatable({
        first = 1,
        last = 0,
        items = {}
    }, Queue)
end

function Queue:enqueue(value)
    self.last = self.last + 1
    self.items[self.last] = value
end

function Queue:dequeue()
    if self:isEmpty() then
        return nil
    end

    local value = self.items[self.first]
    self.items[self.first] = nil
    self.first = self.first + 1

    -- Reset indexes when the queue becomes empty.
    if self.first > self.last then
        self.first = 1
        self.last = 0
    end

    return value
end

function Queue:peek()
    if self:isEmpty() then
        return nil
    end

    return self.items[self.first]
end

function Queue:isEmpty()
    return self.first > self.last
end

function Queue:size()
    return self.last - self.first + 1
end

function Queue:clear()
    self.first = 1
    self.last = 0
    self.items = {}
end

return Queue