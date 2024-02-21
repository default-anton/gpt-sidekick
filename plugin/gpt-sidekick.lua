if vim.g.loaded_gpt_sidekick == 1 then
  return
end
vim.g.loaded_gpt_sidekick = 1

local prompts = require "gpt-sidekick.prompts"
local filetypes = require "gpt-sidekick.filetypes"

local MODELS = { "gpt-3.5-turbo-0125", "gpt-4-0125-preview" }

for _, model in ipairs(MODELS) do
  vim.api.nvim_create_user_command("Ask" .. ((model == MODELS[1]) and "" or "4"), function(opts)
    local filetype = vim.api.nvim_buf_get_option(0, "filetype")
    if filetypes[filetype] == nil then
      vim.print("Error: filetype " .. filetype .. " not supported")
      return
    end

    local language = filetypes[filetype]

    local settings = {
      model = model,
      temperature = 0.2,
      max_tokens = 2048,
      top_p = 1,
      frequency_penalty = 0,
      presence_penalty = 0,
    }

    local prompt = ""
    for key, value in pairs(settings) do
      prompt = prompt .. key:upper() .. ": " .. value .. "\n"
    end

    prompt = prompt .. "\nSYSTEM: " .. string.format(prompts.ask_system_prompt, language.technologies) .. "\n"

    if opts.range == 2 then
      local lines = vim.api.nvim_buf_get_lines(0, opts.line1 - 1, opts.line2, false)
      local context = table.concat(lines, "\n")

      prompt = prompt .. "Context: ```" .. language.code .. "\n" .. context .. "\n```\n\n"
    end

    prompt = prompt .. "USER: "

    -- Create a new floating window
    local buf = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_buf_set_keymap(
      buf,
      "n",
      "<CR>",
      string.format("<cmd>lua require('gpt-sidekick').ask(%d)<CR>", buf),
      {
        nowait = true,
        noremap = true,
        silent = true,
      }
    )

    local winid = vim.api.nvim_get_current_win()
    local width = vim.api.nvim_win_get_width(winid)
    local height = vim.api.nvim_win_get_height(winid)
    local win_width = math.floor(width * 0.8)
    local win_height = math.floor(height * 0.8)
    local row = math.floor((height - win_height) / 2)
    local col = math.floor((width - win_width) / 2)

    vim.api.nvim_open_win(buf, true, {
      relative = "editor",
      style = "minimal",
      width = win_width,
      height = win_height,
      row = row,
      col = col,
      border = "rounded",
      title = "Prompt",
      title_pos = "left",
    })
    local lines = vim.split(prompt, "[\r]?\n")
    vim.api.nvim_buf_set_option(buf, "filetype", "GptSidekickChat")
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    -- Set cursor to the end of the buffer
    vim.api.nvim_win_set_cursor(0, {vim.api.nvim_buf_line_count(buf), 0})
    -- Enter insert mode at the end of the line
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('A', true, false, true), 'n', false)
  end, { range = true })

  vim.api.nvim_create_user_command("Sedit" .. ((model == MODELS[1]) and "" or "4"), function(opts)
    if os.getenv "OPENAI_API_KEY" == nil then
      vim.print "Error: OPENAI_API_KEY environment variable not set"
      return
    end

    local openai = require "openai"
    local client = openai.new(os.getenv "OPENAI_API_KEY")

    local filetype = vim.api.nvim_buf_get_option(0, "filetype")
    if filetypes[filetype] == nil then
      vim.print("Error: filetype " .. filetype .. " not supported")
      return
    end

    local language = filetypes[filetype]
    local prompt = opts.args

    if opts.range == 2 then
      local lines = vim.api.nvim_buf_get_lines(0, opts.line1 - 1, opts.line2, false)
      local context = table.concat(lines, "\n")

      prompt = "Context: ```" .. language.code .. "\n" .. context .. "\n```\n\n" .. prompt
    end

    local status, res = client:chat({
      {
        role = "system",
        content = string.format(prompts.code_system_prompt, language.technologies),
      },
      { role = "user", content = prompt },
    }, {
      model = model,
      temperature = 0.5,
      functions = {
        {
          name = "return_code_to_user",
          description = "Return the code to the user",
          parameters = {
            type = "object",
            properties = {
              code = { type = "string", description = "The code to return" },
            },
          },
          required = { "code" },
        },
      },
      function_call = { name = "return_code_to_user" },
    })

    if status == 200 then
      if res.choices[1].message.function_call == nil then
        vim.print "\nNo function call found. Response:\n"
        vim.print(vim.inspect(res))
        return
      end

      local function_call = res.choices[1].message.function_call

      local ok, arguments = pcall(vim.json.decode, function_call.arguments)

      if ok then
        vim.fn.setreg("+", arguments.code)
        vim.print(arguments.code)
      else
        vim.print "\nError decoding arguments. Function call:\n"
        vim.print(vim.inspect(function_call))
      end
    else
      vim.print("\nError: " .. vim.inspect(res))
    end
  end, { range = true, nargs = "+" })
end
