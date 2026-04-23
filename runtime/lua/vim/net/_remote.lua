local M = {}

local ssh = require('vim.net._ssh')

--- @param uri_str string
--- @return string local_socket path to the local forwarded socket
function M.start(uri_str)
  local uri = ssh.parse_uri(uri_str)
  error('Not implemented yet')
end

return M
