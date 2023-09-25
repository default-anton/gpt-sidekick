if os.getenv "OPENAI_API_KEY" == nil then
  vim.print "Error: OPENAI_API_KEY environment variable not set"
  return
end

local openai = require "openai"
local client = openai.new(os.getenv "OPENAI_API_KEY")

local DEFAULT_SETTTINGS = {
  model = "gpt-3.5-turbo",
  temperature = 0.2,
  max_tokens = 2048,
  top_p = 1,
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
  if os.getenv "OPENAI_API_KEY" == nil then
    vim.print "Error: OPENAI_API_KEY environment variable not set"
    return
  end

  local buf_lines = vim.api.nvim_buf_get_lines(prompt_bufnr, 0, -1, false)
  local full_prompt = table.concat(buf_lines, "\n")

  local prompt_options = parse_prompt(full_prompt)
  local status, res = client:chat(prompt_options.messages, prompt_options.settings)

  if status == 200 then
    if res.choices[1].message.content == nil then
      vim.print("\nNo content found. Response:\n" .. vim.inspect(res))
    end

    local content = res.choices[1].message.content

    local content_lines = vim.split(content, "[\r]?\n")
    -- Add assistant response to buffer
    vim.api.nvim_buf_set_lines(prompt_bufnr, -1, -1, false, { "", "ASSISTANT: " })
    vim.api.nvim_buf_set_lines(prompt_bufnr, -1, -1, false, content_lines)
  else
    vim.print("\nError: " .. vim.inspect(res))
  end
end

return M
