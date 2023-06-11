local function set_display_name(filename, bufnr)
  local res = vim.fn.json_decode(filename);
  if res == nil then
    return;
  end
  vim.api.nvim_buf_set_var(bufnr, "rstrt_filename", res.filename_string);
  local ns_id = vim.api.nvim_buf_get_var(bufnr, "rstrt_ns_id");
  local bg = vim.api.nvim_get_hl_by_name("StatusLine", true).background;
  local counter = 1;
  for _, attributes in pairs(res.definitions) do
    attributes.background = bg;
    vim.api.nvim_set_hl(ns_id, 'User' .. counter, attributes);
    counter = counter + 1;
  end
end

local function generate_on_done_func(bufnr)
  return (function(_, d, _)
    set_display_name(d[1], bufnr);
  end)
end

local function startColorizeJob(args)
  if args.file == "" then
    return;
  end
  vim.fn.jobstart(
    "rstrt --vim-status-line " .. args.file .. " " .. vim.fn.getcwd(),
    {
      on_stdout = generate_on_done_func(args.buf),
      stdout_buffered = true
    }
  );
end

local function set_hl_ns(buf_nbr)
  if pcall(vim.api.nvim_buf_get_var, buf_nbr, "rstrt_ns_id") then
    local ns_id = vim.api.nvim_buf_get_var(buf_nbr, "rstrt_ns_id");
    -- TODO: want to set hl for multiple windows. This is not working.
    -- vim.api.nvim_win_set_hl_ns(vim.g.statusline_winid, ns_id);
    vim.api.nvim_set_hl_ns(ns_id);
  end
end

local function get_filename(buf_nbr)
  if pcall(vim.api.nvim_buf_get_var, buf_nbr, "rstrt_filename") then
    local the_filename = vim.api.nvim_buf_get_var(buf_nbr, "rstrt_filename") or "[No name]";
    return string.format("%s", the_filename);
  else
    return "[No name]";
  end
end

local function get_column_number()
  return vim.fn.col(".")
end

function Status_Line()
  -- TODO: make plugin only extport filename and not the whole statusline.
  local buf_nbr = vim.fn.winbufnr(vim.g.statusline_winid);
  set_hl_ns(buf_nbr);
  return table.concat {
    get_filename(buf_nbr),
    "%m",
    "%=",
    "%#StatusMid#",
    "%l,",
    get_column_number(),
    "%=",
    "%#StatusRight#",
    "%p%%"
  }
end

function Initialize()
  vim.api.nvim_create_autocmd({ "BufAdd" }, {
    desc = "init the rstrt buffer variable",
    callback = function(args)
      if args.file == "" or pcall(vim.api.nvim_buf_get_var, args.buf, "rstrt_is_initialized") then
        return;
      else
        local ns_id = vim.api.nvim_create_namespace("rstrt-" .. args.buf);
        vim.api.nvim_buf_set_var(args.buf, "rstrt_ns_id", ns_id);
        vim.api.nvim_buf_set_var(args.buf, "rstrt_filename", args.file);
        vim.api.nvim_buf_set_var(args.buf, "rstrt_is_initialized", true);
      end
    end,
  })

  -- TODO: should only trigger once per buffer
  vim.api.nvim_create_autocmd({ "BufWinEnter" }, {
    desc = "colorize the filename in the status line with rstrt",
    callback = startColorizeJob
  })
  vim.o.statusline = "%!luaeval('Status_Line()')"
end

local M = {}

function M.init()
  if vim.fn.executable("rstrt") then
    Initialize();
  else
    vim.api.nvim_err_writeln(
    "'rstrt' not found in path. Check out how to install it here: https://github.com/FilipHarald/rstrt#installation");
  end
end

return M
