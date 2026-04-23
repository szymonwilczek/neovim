local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local eq = t.eq

describe('--remote-ssh', function()
  before_each(function()
    clear()
  end)

  describe('argument parsing', function()
    local function run_and_check_exit_code(...)
      local p = n.spawn_wait { args = { ... } }
      eq(1, p.status)
    end

    it('fails without an argument', function()
      run_and_check_exit_code('--remote-ssh')
    end)
  end)

  describe('URI parser', function()
    it('parses ssh://user@host:port', function()
      local uri = n.exec_lua([[
        return require('vim.net._ssh').parse_uri('ssh://root@localhost:2222')
      ]])
      eq('root', uri.user)
      eq('localhost', uri.host)
      eq('2222', uri.port)
    end)

    it('parses user@host', function()
      local uri = n.exec_lua([[
        return require('vim.net._ssh').parse_uri('admin@server.local')
      ]])
      eq('admin', uri.user)
      eq('server.local', uri.host)
      eq(nil, uri.port)
    end)

    it('parses host only', function()
      local uri = n.exec_lua([[
        return require('vim.net._ssh').parse_uri('myalias')
      ]])
      eq(nil, uri.user)
      eq('myalias', uri.host)
      eq(nil, uri.port)
    end)
  end)
end)
