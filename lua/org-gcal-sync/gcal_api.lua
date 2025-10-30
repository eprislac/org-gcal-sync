-- lua/org-gcal-sync/gcal_api.lua
local M = {}

local curl = require("plenary.curl")

M.config = {
  client_id = vim.env.GCAL_ORG_SYNC_CLIENT_ID,
  client_secret = vim.env.GCAL_ORG_SYNC_CLIENT_SECRET,
  token_path = vim.fn.stdpath("data") .. "/org-gcal-sync/token.json",
  calendar_id = "primary",
  calendars = { "primary" },
}

local function read_token()
  local path = M.config.token_path
  if vim.fn.filereadable(path) == 0 then
    return nil
  end
  local content = vim.fn.readfile(path)
  if #content == 0 then
    return nil
  end
  local ok, token = pcall(vim.json.decode, table.concat(content, "\n"))
  if not ok then
    return nil
  end
  return token
end

local function write_token(token)
  vim.fn.mkdir(vim.fn.fnamemodify(M.config.token_path, ":h"), "p")
  vim.fn.writefile({ vim.json.encode(token) }, M.config.token_path)
end

local function is_token_expired(token)
  if not token or not token.expires_at then
    return true
  end
  return os.time() >= token.expires_at
end

local function refresh_access_token(refresh_token)
  local response = curl.post("https://oauth2.googleapis.com/token", {
    body = vim.json.encode({
      client_id = M.config.client_id,
      client_secret = M.config.client_secret,
      refresh_token = refresh_token,
      grant_type = "refresh_token",
    }),
    headers = {
      ["Content-Type"] = "application/json",
    },
  })

  if response.status ~= 200 then
    return nil, "Failed to refresh token: " .. (response.body or "unknown error")
  end

  local ok, data = pcall(vim.json.decode, response.body)
  if not ok then
    return nil, "Failed to parse token response"
  end

  return {
    access_token = data.access_token,
    refresh_token = refresh_token,
    expires_at = os.time() + (data.expires_in or 3600) - 60,
  }
end

function M.get_access_token()
  local token = read_token()
  
  if not token then
    return nil, "No token found. Please authenticate first with :OrgGcalAuth"
  end

  if is_token_expired(token) and token.refresh_token then
    local new_token, err = refresh_access_token(token.refresh_token)
    if not new_token then
      return nil, err
    end
    token = new_token
    write_token(token)
  end

  if is_token_expired(token) then
    return nil, "Token expired. Please re-authenticate with :OrgGcalAuth"
  end

  return token.access_token
end

function M.authenticate()
  if not M.config.client_id or not M.config.client_secret then
    vim.notify("Missing GCAL_ORG_SYNC_CLIENT_ID or GCAL_ORG_SYNC_CLIENT_SECRET environment variables", vim.log.levels.ERROR)
    return
  end

  local redirect_uri = "urn:ietf:wg:oauth:2.0:oob"
  local scope = "https://www.googleapis.com/auth/calendar%20https://www.googleapis.com/auth/tasks"
  
  local auth_url = string.format(
    "https://accounts.google.com/o/oauth2/v2/auth?client_id=%s&redirect_uri=%s&response_type=code&scope=%s&access_type=offline&prompt=consent",
    M.config.client_id,
    redirect_uri,
    scope
  )

  vim.notify("Opening browser for authentication...", vim.log.levels.INFO)
  vim.fn.system(string.format('open "%s" || xdg-open "%s" || start "%s"', auth_url, auth_url, auth_url))
  
  vim.ui.input({ prompt = "Enter authorization code: " }, function(code)
    if not code or code == "" then
      vim.notify("Authentication cancelled", vim.log.levels.WARN)
      return
    end

    local response = curl.post("https://oauth2.googleapis.com/token", {
      body = vim.json.encode({
        code = code,
        client_id = M.config.client_id,
        client_secret = M.config.client_secret,
        redirect_uri = redirect_uri,
        grant_type = "authorization_code",
      }),
      headers = {
        ["Content-Type"] = "application/json",
      },
    })

    if response.status ~= 200 then
      vim.notify("Authentication failed: " .. (response.body or "unknown error"), vim.log.levels.ERROR)
      return
    end

    local ok, data = pcall(vim.json.decode, response.body)
    if not ok then
      vim.notify("Failed to parse authentication response", vim.log.levels.ERROR)
      return
    end

    local token = {
      access_token = data.access_token,
      refresh_token = data.refresh_token,
      expires_at = os.time() + (data.expires_in or 3600) - 60,
    }

    write_token(token)
    vim.notify("Authentication successful!", vim.log.levels.INFO)
  end)
end

function M.list_events(time_min, time_max, calendar_id)
  local access_token, err = M.get_access_token()
  if not access_token then
    return nil, err
  end

  calendar_id = calendar_id or M.config.calendar_id
  
  local url = string.format(
    "https://www.googleapis.com/calendar/v3/calendars/%s/events?timeMin=%s&timeMax=%s&singleEvents=true&orderBy=startTime",
    calendar_id,
    time_min or os.date("!%Y-%m-%dT%H:%M:%SZ"),
    time_max or os.date("!%Y-%m-%dT%H:%M:%SZ", os.time() + 30 * 24 * 60 * 60)
  )

  local response = curl.get(url, {
    headers = {
      ["Authorization"] = "Bearer " .. access_token,
      ["Accept"] = "application/json",
    },
  })

  if response.status ~= 200 then
    return nil, "Failed to fetch events: " .. (response.body or "unknown error")
  end

  local ok, data = pcall(vim.json.decode, response.body)
  if not ok then
    return nil, "Failed to parse events response"
  end

  return data.items or {}
end

function M.create_event(event_data, calendar_id)
  local access_token, err = M.get_access_token()
  if not access_token then
    return nil, err
  end

  calendar_id = calendar_id or M.config.calendar_id
  
  local url = string.format(
    "https://www.googleapis.com/calendar/v3/calendars/%s/events",
    calendar_id
  )

  local response = curl.post(url, {
    body = vim.json.encode(event_data),
    headers = {
      ["Authorization"] = "Bearer " .. access_token,
      ["Content-Type"] = "application/json",
    },
  })

  if response.status ~= 200 and response.status ~= 201 then
    return nil, "Failed to create event: " .. (response.body or "unknown error")
  end

  local ok, data = pcall(vim.json.decode, response.body)
  if not ok then
    return nil, "Failed to parse create event response"
  end

  return data
end

function M.update_event(event_id, event_data, calendar_id)
  local access_token, err = M.get_access_token()
  if not access_token then
    return nil, err
  end

  calendar_id = calendar_id or M.config.calendar_id
  
  local url = string.format(
    "https://www.googleapis.com/calendar/v3/calendars/%s/events/%s",
    calendar_id,
    event_id
  )

  local response = curl.put(url, {
    body = vim.json.encode(event_data),
    headers = {
      ["Authorization"] = "Bearer " .. access_token,
      ["Content-Type"] = "application/json",
    },
  })

  if response.status ~= 200 then
    return nil, "Failed to update event: " .. (response.body or "unknown error")
  end

  local ok, data = pcall(vim.json.decode, response.body)
  if not ok then
    return nil, "Failed to parse update event response"
  end

  return data
end

function M.delete_event(event_id, calendar_id)
  local access_token, err = M.get_access_token()
  if not access_token then
    return nil, err
  end

  calendar_id = calendar_id or M.config.calendar_id
  
  local url = string.format(
    "https://www.googleapis.com/calendar/v3/calendars/%s/events/%s",
    calendar_id,
    event_id
  )

  local response = curl.delete(url, {
    headers = {
      ["Authorization"] = "Bearer " .. access_token,
    },
  })

  if response.status ~= 204 and response.status ~= 200 then
    return nil, "Failed to delete event: " .. (response.body or "unknown error")
  end

  return true
end

function M.check_api_reachable()
  local response = curl.get("https://www.googleapis.com/calendar/v3/users/me/calendarList", {
    headers = {
      ["Accept"] = "application/json",
    },
    timeout = 5000,
  })
  return response.status == 401 or response.status == 200
end

function M.list_calendars()
  local access_token, err = M.get_access_token()
  if not access_token then
    return nil, err
  end

  local response = curl.get("https://www.googleapis.com/calendar/v3/users/me/calendarList", {
    headers = {
      ["Authorization"] = "Bearer " .. access_token,
      ["Accept"] = "application/json",
    },
  })

  if response.status ~= 200 then
    return nil, "Failed to fetch calendars: " .. (response.body or "unknown error")
  end

  local ok, data = pcall(vim.json.decode, response.body)
  if not ok then
    return nil, "Failed to parse calendars response"
  end

  return data.items or {}
end

function M.expand_recurring_event(event, start_date, end_date)
  if not event.recurrence then
    return { event }
  end
  
  local instances = {}
  local access_token, err = M.get_access_token()
  if not access_token then
    return { event }
  end
  
  local url = string.format(
    "https://www.googleapis.com/calendar/v3/calendars/%s/events/%s/instances?timeMin=%s&timeMax=%s",
    event.calendarId or M.config.calendar_id,
    event.id,
    start_date,
    end_date
  )
  
  local response = curl.get(url, {
    headers = {
      ["Authorization"] = "Bearer " .. access_token,
      ["Accept"] = "application/json",
    },
  })
  
  if response.status == 200 then
    local ok, data = pcall(vim.json.decode, response.body)
    if ok and data.items then
      return data.items
    end
  end
  
  return { event }
end

-- Google Tasks API functions
function M.get_default_task_list()
  local access_token, err = M.get_access_token()
  if not access_token then
    return nil, err
  end

  local response = curl.get("https://tasks.googleapis.com/tasks/v1/users/@me/lists", {
    headers = {
      ["Authorization"] = "Bearer " .. access_token,
      ["Accept"] = "application/json",
    },
  })

  if response.status ~= 200 then
    return nil, "Failed to fetch task lists: " .. (response.body or "unknown error")
  end

  local ok, data = pcall(vim.json.decode, response.body)
  if not ok or not data.items or #data.items == 0 then
    return nil, "No task lists found"
  end

  return data.items[1].id
end

function M.create_task(task_data, task_list_id)
  local access_token, err = M.get_access_token()
  if not access_token then
    return nil, err
  end

  if not task_list_id then
    task_list_id, err = M.get_default_task_list()
    if not task_list_id then
      return nil, err
    end
  end

  local url = string.format(
    "https://tasks.googleapis.com/tasks/v1/lists/%s/tasks",
    task_list_id
  )

  local response = curl.post(url, {
    body = vim.json.encode(task_data),
    headers = {
      ["Authorization"] = "Bearer " .. access_token,
      ["Content-Type"] = "application/json",
    },
  })

  if response.status ~= 200 and response.status ~= 201 then
    return nil, "Failed to create task: " .. (response.body or "unknown error")
  end

  local ok, data = pcall(vim.json.decode, response.body)
  if not ok then
    return nil, "Failed to parse create task response"
  end

  return data
end

function M.list_tasks(task_list_id)
  local access_token, err = M.get_access_token()
  if not access_token then
    return nil, err
  end

  if not task_list_id then
    task_list_id, err = M.get_default_task_list()
    if not task_list_id then
      return nil, err
    end
  end

  local url = string.format(
    "https://tasks.googleapis.com/tasks/v1/lists/%s/tasks",
    task_list_id
  )

  local response = curl.get(url, {
    headers = {
      ["Authorization"] = "Bearer " .. access_token,
      ["Accept"] = "application/json",
    },
  })

  if response.status ~= 200 then
    return nil, "Failed to fetch tasks: " .. (response.body or "unknown error")
  end

  local ok, data = pcall(vim.json.decode, response.body)
  if not ok then
    return nil, "Failed to parse tasks response"
  end

  return data.items or {}
end

function M.update_task(task_id, task_data, task_list_id)
  local access_token, err = M.get_access_token()
  if not access_token then
    return nil, err
  end

  if not task_list_id then
    task_list_id, err = M.get_default_task_list()
    if not task_list_id then
      return nil, err
    end
  end

  local url = string.format(
    "https://tasks.googleapis.com/tasks/v1/lists/%s/tasks/%s",
    task_list_id,
    task_id
  )

  local response = curl.put(url, {
    body = vim.json.encode(task_data),
    headers = {
      ["Authorization"] = "Bearer " .. access_token,
      ["Content-Type"] = "application/json",
    },
  })

  if response.status ~= 200 then
    return nil, "Failed to update task: " .. (response.body or "unknown error")
  end

  local ok, data = pcall(vim.json.decode, response.body)
  if not ok then
    return nil, "Failed to parse update task response"
  end

  return data
end

function M.delete_task(task_id, task_list_id)
  local access_token, err = M.get_access_token()
  if not access_token then
    return nil, err
  end

  if not task_list_id then
    task_list_id, err = M.get_default_task_list()
    if not task_list_id then
      return nil, err
    end
  end

  local url = string.format(
    "https://tasks.googleapis.com/tasks/v1/lists/%s/tasks/%s",
    task_list_id,
    task_id
  )

  local response = curl.delete(url, {
    headers = {
      ["Authorization"] = "Bearer " .. access_token,
    },
  })

  if response.status ~= 204 and response.status ~= 200 then
    return nil, "Failed to delete task: " .. (response.body or "unknown error")
  end

  return true
end

return M
