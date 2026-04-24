local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local clear = n.clear
local eq = t.eq

describe('vim.net._remote', function()
  local fake_bin_dir

  local function setup_fake_ssh(behavior)
    behavior = behavior or {}
    fake_bin_dir = t.tmpname()
    os.remove(fake_bin_dir)
    vim.uv.fs_mkdir(fake_bin_dir, 511)
    local fake_ssh_path = fake_bin_dir .. '/ssh'

    local script = [=[
#!/usr/bin/env bash
ARGS="$*"

if [[ "$ARGS" == *"uname -s && uname -m"* ]]; then
]=] .. (behavior.uname or [=[
  echo "Linux"
  echo "x86_64"
]=]) .. [=[
  exit 0
fi

if [[ "$ARGS" == *"-L"* ]]; then
  if [[ "$ARGS" != *"ControlMaster"* ]]; then
    echo "FAIL: Multiplexing flags missing!" >&2
    exit 1
  fi
]=] .. (behavior.tunnel or [=[
  echo "Password: " >&2
  read -r PASS
  PASS=$(echo "$PASS" | tr -d '\r')
  if [ "$PASS" != "secret" ]; then
    echo "Access denied" >&2
    exit 1
  fi
  SOCK=$(echo "$ARGS" | grep -oE '\-L [^:]+' | cut -d' ' -f2)
  echo "ARGS=$ARGS" > /tmp/debug_fake_ssh.txt
  echo "SOCK=$SOCK" >> /tmp/debug_fake_ssh.txt
  touch "$SOCK"
  sleep 60 &
  exit 0
]=]) .. [=[
fi

if [[ "$ARGS" == *"TARGET_VER"* ]]; then
]=] .. (behavior.installer or [=[
  echo "Installing Neovim..." >&2
  exit 0
]=]) .. [=[
fi

if [[ "$ARGS" == *"mkdir -p"* ]]; then
  echo "Config synced!" >&2
  exit 0
fi

if [[ "$ARGS" == *"-O"*"exit"* ]]; then
  exit 0
fi

echo "Unexpected SSH command: $ARGS" >&2
exit 1
]=]
    t.write_file(fake_ssh_path, script)
    vim.uv.fs_chmod(fake_ssh_path, 493)

    n.exec_lua(string.format(
      [[
      _G.orig_path = vim.fn.getenv('PATH')
      vim.fn.setenv('PATH', %q .. ':' .. _G.orig_path)
      vim.fn.setenv('NVIM_TEST_MOCK_UI', '1')
    ]],
      fake_bin_dir
    ))
  end

  local function teardown_fake_ssh()
    if fake_bin_dir then
      n.exec_lua([[
        if _G.orig_path then
          vim.fn.setenv('PATH', _G.orig_path)
        end
      ]])
    end
  end

  before_each(function()
    clear()
  end)

  after_each(function()
    teardown_fake_ssh()
  end)

  describe('Remote Engine (Introspection)', function()
    it('detects linux x86_64 successfully', function()
      setup_fake_ssh({
        uname = [[
          echo "Linux"
          echo "x86_64"
        ]],
      })
      local res = n.exec_lua([[
        return { require('vim.net._remote').get_system_info({ host = 'server' }) }
      ]])
      eq('linux', res[1])
      eq('x86_64', res[2])
    end)

    it('detects macos arm64 successfully', function()
      setup_fake_ssh({
        uname = [[
          echo "Darwin"
          echo "arm64"
        ]],
      })
      local res = n.exec_lua([[
        return { require('vim.net._remote').get_system_info({ host = 'server' }) }
      ]])
      eq('darwin', res[1])
      eq('arm64', res[2])
    end)

    it('fails fast on Windows', function()
      setup_fake_ssh({
        uname = [[
          echo "MSYS_NT-10.0-19045"
          echo "x86_64"
        ]],
      })
      local status, err = pcall(function()
        n.exec_lua([[
          require('vim.net._remote').get_system_info({ host = 'server' })
        ]])
      end)
      eq(false, status)
      assert(string.match(err, 'Windows targets are not supported'))
    end)
  end)

  describe('Remote Engine (Orchestration)', function()
    it('injects password and returns local socket', function()
      setup_fake_ssh()
      local res = n.exec_lua([[
        _G.inputs_requested = {}
        vim.ui.input = function(opts, on_confirm)
          table.insert(_G.inputs_requested, opts.prompt)
          on_confirm("secret")
        end
        local sock = require('vim.net._remote').start('user@test-server')
        return { sock, _G.inputs_requested }
      ]])

      local sock = res[1]
      local inputs = res[2]

      assert(sock:match('_remote_nvim%.sock$'))
      eq('Password: ', inputs[1])
    end)
  end)
end)
