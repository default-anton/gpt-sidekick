local openai = {
  DATA = "data",
  DONE = "done",
}

function openai.new(api_key)
  return setmetatable({ api_key = api_key }, { __index = openai })
end

function openai:chat(messages, settings, callback)
  callback = vim.schedule_wrap(callback)

  local data = {
    model = settings.model or "gpt-3.5-turbo",
    stream = settings.stream,
    temperature = settings.temperature or 0.2,
    max_tokens = settings.max_tokens or 4095,
    top_p = settings.top_p or 1,
    frequency_penalty = settings.frequency_penalty or 0,
    presence_penalty = settings.presence_penalty or 0,
    messages = messages
  }

  local curl_args = {
    "--silent",
    "--no-buffer",
    "https://api.openai.com/v1/chat/completions",
    "-H", "Content-Type: application/json",
    "-H", "Authorization: Bearer " .. self.api_key,
    "--data", vim.json.encode(data),
  }

  require 'plenary.job':new({
    command = "curl",
    args = curl_args,
    on_stdout = function(_, line)
      if not line or #line == 0 then
        return
      end

      line = string.gsub(line, "^data: ", "")
      if line == "[DONE]" then
        callback(openai.DONE, "")
        return
      end

      local ok, response = pcall(vim.json.decode, line)

      if ok and response and response.choices and response.choices[1] and response.choices[1] then
        if response.choices[1].delta and response.choices[1].delta.content then
          callback(openai.DATA, response.choices[1].delta.content)
        end
      else
        vim.schedule(function()
          vim.notify("each line Error: " .. line, vim.log.levels.ERROR)
        end)
      end
    end,
    on_exit = function(_, return_val)
      if return_val == 0 then
        return
      end

      vim.schedule(function()
        vim.notify("Completed with exit code: " .. return_val, vim.log.levels.ERROR)
      end)
    end,
  }):start()
end

return openai
