if vim.g.loaded_gpt_sidekick == 1 then
  return
end
vim.g.loaded_gpt_sidekick = 1

local prompts = require "gpt-sidekick.prompts"
local filetypes = require "gpt-sidekick.filetypes"

local MODELS = {
  "gpt-4-turbo-preview",
  "gpt-3.5-turbo",
  "mixtral-8x7b-32768",
}

vim.api.nvim_create_user_command("Ask", function(opts)
  local filetype = vim.api.nvim_buf_get_option(0, "filetype")
  local language = filetypes[filetype]
  local model = #opts.fargs == 0 and MODELS[1] or opts.fargs[1]

  if model == nil then
    error("Invalid model")
  end

  local settings = {
    model = model,
    temperature = 0.2,
    max_tokens = 2048,
    top_p = 1,
  }

  local prompt = ""
  for key, value in pairs(settings) do
    prompt = prompt .. key:upper() .. ": " .. value .. "\n"
  end

  if language == nil then
    prompt = prompt .. "\nSYSTEM: \nUSER: "
  else
    prompt = prompt .. "\nSYSTEM: " .. string.format(prompts.ask_system_prompt, language.technologies) .. "\n"

    if opts.range == 2 then
      local lines = vim.api.nvim_buf_get_lines(0, opts.line1 - 1, opts.line2, false)
      local context = table.concat(lines, "\n")

      prompt = prompt .. "Context: ```" .. language.code .. "\n" .. context .. "\n```\n\n"
    end

    prompt = prompt .. "USER: "
  end

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
  vim.api.nvim_win_set_cursor(0, { vim.api.nvim_buf_line_count(buf), 0 })
  -- Enter insert mode at the end of the line
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('A', true, false, true), 'n', false)
end, {
  range = true,
  nargs = "?",
  complete = function(ArgLead, CmdLine, CursorPos)
    return MODELS
  end,
})
