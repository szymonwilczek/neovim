local M = {}

local ssh = require('vim.net._ssh')

--- @param uri table
--- @return string os, string arch
function M.get_system_info(uri)
  local ssh_cmd = { 'ssh', '-T' }
  if uri.port then
    table.insert(ssh_cmd, '-p')
    table.insert(ssh_cmd, uri.port)
  end
  local target = uri.host
  if uri.user then
    target = uri.user .. '@' .. uri.host
  end
  table.insert(ssh_cmd, target)
  table.insert(ssh_cmd, 'uname -s && uname -m')

  local obj = vim.system(ssh_cmd, { text = true }):wait()
  if obj.code ~= 0 then
    error('Failed to detect remote system info: ' .. (obj.stderr or ''))
  end

  local lines = vim.split(vim.trim(obj.stdout), '\n', { plain = true })
  if #lines < 2 then
    error('Unexpected output from system info detection: ' .. obj.stdout)
  end

  local os = vim.trim(lines[1]):lower()
  local arch = vim.trim(lines[2]):lower()

  if os:match('msys') or os:match('windows') or os:match('mingw') or os:match('cygwin') then
    error('Not implemented yet')
  end

  return os, arch
end

--- @param uri_str string
--- @return string local_socket path to the local forwarded socket
function M.start(uri_str)
  local uri = ssh.parse_uri(uri_str)
  local os, arch = M.get_system_info(uri)

  error('Not implemented yet')
end

return M
