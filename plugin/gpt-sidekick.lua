if vim.g.loaded_gpt_sidekick == 1 then
  return
end
vim.g.loaded_gpt_sidekick = 1

local code_system_prompt = [[
As an expert Full Stack Developer with over a decade of experience, demonstrating mastery in %s, your role is to assist me. When coding, deliver clean, efficient, and commented code according to best industry practices. Your tasks will include creating and debugging software and offering solutions to programming challenges.
]]

local ask_system_prompt = [[
As an expert Full Stack Developer with over a decade of experience, demonstrating mastery in %s, your role is to assist me. When answering my questions, ensure that you provide comprehensive, precise, and easy-to-understand responses. When coding, deliver clean, efficient, and commented code according to best industry practices. You will also be expected to explain complex concepts in a simple, accessible way. Your tasks will include creating and debugging software, offering solutions to programming challenges, and giving advice on the optimal use of the technologies mentioned. In addition, be ready to guide me step-by-step through each coding process.
]]

local filetypes = {
  ruby = { code = "ruby", technologies = "Ruby, Ruby on Rails and RSpec" },
  eruby = { code = "erb", technologies = "Ruby, Ruby on Rails and RSpec" },
  lua = { code = "lua", technologies = "Neovim and Lua" },
  javascript = { code = "js", technologies = "JavaScript, HTML and CSS" },
  javascriptreact = { code = "jsx", technologies = "JavaScript, React, HTML and CSS" },
  typescript = { code = "ts", technologies = "JavaScript, TypeScript, HTML and CSS" },
  typescriptreact = { code = "tsx", technologies = "JavaScript, TypeScript, React, HTML and CSS" },
  python = { code = "python", technologies = "Python" },
}

local MODELS = { "gpt-3.5-turbo", "gpt-4" }

for _, model in ipairs(MODELS) do
  vim.api.nvim_create_user_command("Sask" .. ((model == MODELS[1]) and "" or "4"), function(opts)
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
        content = string.format(ask_system_prompt, language.technologies),
      },
      { role = "user", content = prompt },
    }, {
      model = model,
      temperature = 0.5,
    })

    if status == 200 then
      if res.choices[1].message.content == nil then
        vim.print("\nNo content found. Response:\n" .. vim.inspect(res))
        return
      end

      vim.print(res.choices[1].message.content)
    else
      vim.print("\nError: " .. vim.inspect(res))
    end
  end, { range = true, nargs = "+" })

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
        content = string.format(code_system_prompt, language.technologies),
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
