local DEFAULT_SETTTINGS = {
  model = "gpt-3.5-turbo",
  temperature = 0.2,
  max_tokens = 4095,
  top_p = 1,
  stream = true,
  frequency_penalty = 0,
  presence_penalty = 0,
}

local M = {}

function M.get_prompt(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local full_prompt = table.concat(lines, "\n")
  return full_prompt
end

local function parse_prompt(prompt)
  local options = {
    messages = {},
    settings = vim.deepcopy(DEFAULT_SETTTINGS),
  }
  for line in prompt:gmatch "[^\r\n]+" do
    if line:sub(1, 1) == "#" then
      goto continue
    end
    if line:match "^%s*$" then
      goto continue
    end

    if line:sub(1, 7) == "SYSTEM:" then
      options.messages[#options.messages + 1] = {
        role = "system",
        content = line:sub(8),
      }
      goto continue
    end
    if line:sub(1, 5) == "USER:" then
      options.messages[#options.messages + 1] = {
        role = "user",
        content = line:sub(6),
      }
      goto continue
    end
    if line:sub(1, 10) == "ASSISTANT:" then
      options.messages[#options.messages + 1] = {
        role = "assistant",
        content = line:sub(11),
      }
      goto continue
    end

    local key, value = line:match "([^:]+):%s*(.+)"
    if key ~= nil and value ~= nil and options.settings[key:lower()] ~= nil then
      key = key:lower()
      if type(options.settings[key]) == "number" then
        options.settings[key] = tonumber(value)
      else
        options.settings[key] = value
      end
      goto continue
    end

    if #options.messages > 0 then
      options.messages[#options.messages].content = options.messages[#options.messages].content .. "\n" .. line
    end

    ::continue::
  end

  return options
end

function M.ask(prompt_bufnr)
  local buf_lines = vim.api.nvim_buf_get_lines(prompt_bufnr, 0, -1, false)
  local full_prompt = table.concat(buf_lines, "\n")

  local prompt_options = parse_prompt(full_prompt)

  if os.getenv "OPENAI_API_KEY" == nil then
    vim.schedule(function()
      vim.notify("Error: OPENAI_API_KEY environment variable not set", vim.log.levels.ERROR)
    end)
    return
  end

  local openai = require "gpt-sidekick.openai"
  local client = openai.new(os.getenv "OPENAI_API_KEY")
  local buffer = "ASSISTANT: "
  client:chat(prompt_options.messages, prompt_options.settings, function(chars)
    buffer = buffer .. chars

    if buffer:find "\n" then
      local lines = {}
      for line in buffer:gmatch "[^\r\n]+" do
        lines[#lines + 1] = line
      end
      vim.api.nvim_buf_set_lines(prompt_bufnr, -1, -1, false, lines)
      buffer = ""
    end
  end)
end

return M
