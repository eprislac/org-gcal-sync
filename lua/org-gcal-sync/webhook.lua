-- lua/org-gcal-sync/webhook.lua
local M = {}
local uv = vim.loop

M.server = nil
M.config = {}

local function handle_notification(data)
  local ok, parsed = pcall(vim.json.decode, data)
  if not ok then
    vim.notify("Webhook: Invalid JSON received", vim.log.levels.WARN)
    return
  end
  
  if parsed.kind == "api#channel" and parsed.resourceState then
    vim.notify("Calendar changed, syncing...", vim.log.levels.INFO)
    vim.schedule(function()
      local sync = require("org-gcal-sync")
      sync.import_gcal()
    end)
  end
end

local function handle_request(request)
  local headers = {}
  local body = ""
  local in_headers = true
  
  for line in request:gmatch("[^\r\n]+") do
    if in_headers then
      if line == "" then
        in_headers = false
      else
        local key, value = line:match("^([^:]+):%s*(.+)$")
        if key then
          headers[key:lower()] = value
        end
      end
    else
      body = body .. line
    end
  end
  
  if headers["x-goog-channel-id"] then
    handle_notification(body)
    return "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n"
  elseif headers["x-goog-resource-state"] then
    handle_notification(body)
    return "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n"
  end
  
  return "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n"
end

function M.start(config)
  M.config = config or {}
  local port = M.config.port or 8080
  local host = M.config.host or "127.0.0.1"
  
  if M.server then
    vim.notify("Webhook server already running", vim.log.levels.WARN)
    return
  end
  
  M.server = uv.new_tcp()
  M.server:bind(host, port)
  
  M.server:listen(128, function(err)
    if err then
      vim.notify("Webhook server error: " .. err, vim.log.levels.ERROR)
      return
    end
    
    local client = uv.new_tcp()
    M.server:accept(client)
    
    client:read_start(function(read_err, chunk)
      if read_err then
        client:close()
        return
      end
      
      if chunk then
        local response = handle_request(chunk)
        client:write(response)
        client:close()
      else
        client:close()
      end
    end)
  end)
  
  vim.notify(string.format("Webhook server started on %s:%d", host, port), vim.log.levels.INFO)
end

function M.stop()
  if M.server then
    M.server:close()
    M.server = nil
    vim.notify("Webhook server stopped", vim.log.levels.INFO)
  end
end

function M.subscribe_calendar(calendar_id, gcal_api)
  local webhook_url = string.format("http://%s:%d/webhook", 
    M.config.public_host or "localhost",
    M.config.port or 8080
  )
  
  local channel_id = vim.fn.sha256(calendar_id .. os.time())
  local expiration = os.time() + (7 * 24 * 60 * 60) * 1000
  
  local access_token, err = gcal_api.get_access_token()
  if not access_token then
    return nil, err
  end
  
  local curl = require("plenary.curl")
  local response = curl.post(
    string.format(
      "https://www.googleapis.com/calendar/v3/calendars/%s/events/watch",
      calendar_id
    ),
    {
      body = vim.json.encode({
        id = channel_id,
        type = "web_hook",
        address = webhook_url,
        expiration = tostring(expiration),
      }),
      headers = {
        ["Authorization"] = "Bearer " .. access_token,
        ["Content-Type"] = "application/json",
      },
    }
  )
  
  if response.status ~= 200 then
    return nil, "Failed to subscribe to calendar: " .. (response.body or "unknown error")
  end
  
  local ok, data = pcall(vim.json.decode, response.body)
  if not ok then
    return nil, "Failed to parse subscription response"
  end
  
  return data
end

return M
