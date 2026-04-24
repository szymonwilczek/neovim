local t = require('test.testutil')
local parser = require('vim.net._ssh')
local eq = t.eq

describe('SSH parser', function()
  it('parses SSH configuration strings', function()
    local config = [[
      Host *
        ConnectTimeout 10
        ServerAliveInterval 60
        ServerAliveCountMax 3
        # Use a specific key for any host not otherwise specified
        # IdentityFile ~/.ssh/id_rsa

      Host=dev
        HostName=dev.example.com
        User=devuser
        Port=2222
        IdentityFile=~/.ssh/id_rsa_dev

      Host prod test
        HostName 198.51.100.10
        User admin
        Port 22
        IdentityFile ~/.ssh/id_rsa_prod
        ForwardAgent yes

      Host test
        IdentitiesOnly yes

      Host "quoted string"
        User quote
        Port 22

      Match host foo host gh
        HostName github.com
        User git
        IdentityFile ~/.ssh/id_rsa_github
        IdentitiesOnly yes
    ]]

    eq({
      'dev',
      'prod',
      'test',
      'quoted string',
      'gh',
    }, parser.parse_ssh_config(config))
  end)

  it('fails when a quote is not closed', function()
    local config = [[
      Host prod dev "test prod my
        HostName 198.51.100.10
        User admin
        Port 22
        IdentityFile ~/.ssh/id_rsa_prod
        ForwardAgent yes
    ]]

    local ok, _ = pcall(parser.parse_ssh_config, config)
    eq(false, ok)
  end)

  it('fails when the line ends with a single backslash', function()
    local config = [[
      Host prod test
        HostName 198.51.100.10
        User admin\
        Port 22
        IdentityFile ~/.ssh/id_rsa_prod
        ForwardAgent yes
    ]]

    local ok, _ = pcall(parser.parse_ssh_config, config)
    eq(false, ok)
  end)

  describe('URI parser', function()
    it('parses ssh://user@host:port', function()
      local uri = parser.parse_uri('ssh://root@localhost:2222')
      eq('root', uri.user)
      eq('localhost', uri.host)
      eq('2222', uri.port)
    end)

    it('parses user@host', function()
      local uri = parser.parse_uri('admin@server.local')
      eq('admin', uri.user)
      eq('server.local', uri.host)
      eq(nil, uri.port)
    end)

    it('parses host only', function()
      local uri = parser.parse_uri('myalias')
      eq(nil, uri.user)
      eq('myalias', uri.host)
      eq(nil, uri.port)
    end)
  end)
end)
