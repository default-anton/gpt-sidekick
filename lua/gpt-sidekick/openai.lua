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
    messages = messages
  }

  local url = "https://api.openai.com/v1/chat/completions"
  if data.model == "mixtral-8x7b-32768" then
    url = "https://api.groq.com/openai/v1/chat/completions"
  end

  local curl_args = {
    "--silent",
    "--no-buffer",
    url,
    "-H", "Content-Type: application/json",
    "-H", "Authorization: Bearer " .. self.api_key,
    "--data", vim.json.encode(data),
  }

  require 'plenary.job':new({
    command = "curl",
    args = curl_args,
    on_stdout = function(_, chars)
      if not chars or #chars == 0 then
        return
      end

      chars = string.gsub(chars, "^data: ", "")
      if chars == "[DONE]" then
        callback(openai.DONE, "")
        return
      end

      local ok, response = pcall(vim.json.decode, chars)

      if ok and response and response.choices and response.choices[1] and response.choices[1] then
        if response.choices[1].delta and response.choices[1].delta.content then
          callback(openai.DATA, response.choices[1].delta.content)
        end
      else
        vim.schedule(function()
          vim.notify("chars Error: " .. chars, vim.log.levels.ERROR)
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
