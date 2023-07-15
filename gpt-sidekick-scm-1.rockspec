local MODREV, SPECREV = "scm", "-1"
rockspec_format = "3.0"
package = "gpt-sidekick"
version = MODREV .. SPECREV

description = {
  summary = "Everyone needs a sidekick",
  detailed = [[
  I'm lazy, and I hate to copy & paste code to ChatGPT, so I wrote this.
  ]],
  labels = { "neovim", "plugin", "chatgpt", "gpt" },
  homepage = "https://github.com/default-anton/gpt-sidekick",
  license = "MIT",
}

dependencies = {
  "lua >= 5.1, < 5.4",
  "plenary.nvim",
  "lua-openai",
}

source = {
  url = "git://github.com/default-anton/gpt-sidekick",
}

build = {
  type = "builtin",
  copy_directories = {
    "doc",
    "plugin",
    "scripts",
  },
}
