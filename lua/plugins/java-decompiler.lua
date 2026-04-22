-- lua/plugins/java-decompiler.lua
-- This plugin will handle automatic decompilation of Java .class and .jar files.

local Job = require("plenary.job")

return {
  "nvim-lua/plenary.nvim", -- Dependency for running async jobs
  event = "VeryLazy",
  config = function()
    local M = {}

    -- Paths to the helper Python scripts
    local script_dir = vim.fn.fnamemodify(vim.fn.resolve(vim.api.nvim_get_runtime_file("lua/plugins/java-decompiler.lua", false)[1]), ":h:h:h") .. "/scripts"
    local resolve_script = script_dir .. "/java-resolve-deps.py"
    local batch_script = script_dir .. "/java-decompile-imports.py"

    -- State tracking tables
    local decompiled_cache = {} -- Tracks already processed files to avoid loops
    local failed_fqns = {} -- Tracks fully qualified names that failed to decompile
    local debounce_timer = nil

    --- Computes the root directory of the source tree based on the package declaration.
    -- @param java_file string: Path to the decompiled .java file.
    -- @param classdir string: The directory of the original .class file.
    -- @return string: The calculated root directory of the project.
    function M.compute_tree_root(java_file, classdir)
      local lines = {}
      local file = io.open(java_file, "r")
      if not file then return classdir end
      for i=1,30 do
        local line = file:read("l")
        if not line then break end
        table.insert(lines, line)
      end
      file:close()

      local pkg = ""
      for _, line in ipairs(lines) do
        local match = line:match("^%s*package%s+([a-zA-Z0-9_.]+);")
        if match then
          pkg = match
          break
        end
      end

      if pkg == "" then return classdir end

      local suffix = "/" .. pkg:gsub("%.", "/")
      if classdir:find(suffix:gsub("/", "\\/") .. "$") then
        return classdir:gsub(suffix:gsub("/", "\\/") .. "$", "")
      end

      return classdir
    end

    --- Ensures the directory has basic Eclipse JDT project files (.project, .classpath).
    -- This helps the Java LSP (jdtls) recognize it as a valid project.
    -- @param tree_root string: The root directory of the project.
    function M.ensure_project_files(tree_root)
      local project_file = tree_root .. "/.project"
      if vim.fn.filereadable(project_file) == 0 then
        vim.fn.writefile({
          '<?xml version="1.0" encoding="UTF-8"?>',
          '<projectDescription>',
          '    <name>decompiled</name>',
          '    <natures><nature>org.eclipse.jdt.core.javanature</nature></natures>',
          '    <buildSpec>',
          '        <buildCommand><name>org.eclipse.jdt.core.javabuilder</name></buildCommand>',
          '    </buildSpec>',
          '</projectDescription>',
        }, project_file)
      end

      local classpath_file = tree_root .. "/.classpath"
      if vim.fn.filereadable(classpath_file) == 0 then
        vim.fn.writefile({
          '<?xml version="1.0" encoding="UTF-8"?>',
          '<classpath>',
          '    <classpathentry kind="src" path="" excluding="**/*.class|**/sources/**|**/target/**|.jdt-bin/"/>',
          '    <classpathentry kind="con" path="org.eclipse.jdt.launching.JRE_CONTAINER"/>',
          '    <classpathentry kind="output" path=".jdt-bin"/>',
          '</classpath>',
        }, classpath_file)
      end
    end

--- Main function to decompile a .class file.
function M.decompile_class()
  local class_file = vim.fn.expand("%:p")
  -- Check for .class magic bytes
  local magic_bytes_tbl = vim.fn.readfile(class_file, "b", 1)
  if not magic_bytes_tbl or #magic_bytes_tbl == 0 then return end
  local magic_bytes = magic_bytes_tbl[1]
  if not magic_bytes or not magic_bytes:match("^\202\254\186\190") then
    return
  end

  local class_dir = vim.fn.fnamemodify(class_file, ":h")
  local java_basename = vim.fn.fnamemodify(class_file, ":t:r") .. ".java"
  local dest_file = class_dir .. "/" .. java_basename

  if decompiled_cache[class_file] then return end
  decompiled_cache[class_file] = true

  if vim.fn.filereadable(dest_file) == 0 then
    print("Decompiling " .. vim.fn.fnamemodify(class_file, ":t") .. "...")
    local tmp_dir = vim.fn.tempname()
    Job:new({
      command = "jadx",
      args = { "--no-res", "-d", tmp_dir, class_file },
      on_exit = function(j, return_val)
        vim.schedule(function()
          if return_val ~= 0 then
            print("JADX decompilation failed for " .. class_file)
            vim.fn.delete(tmp_dir, "rf")
            return
          end
          local java_files = vim.fn.glob(tmp_dir .. "/**/*.java", 0, 1)
          if #java_files > 0 then
            vim.fn.writefile(vim.fn.readfile(java_files[1]), dest_file)
            print("Decompilation successful.")
            local current_buf = vim.api.nvim_get_current_buf()
            vim.cmd("silent edit " .. vim.fn.fnameescape(dest_file))
            if vim.api.nvim_buf_is_valid(current_buf) and vim.bo[current_buf].filetype == 'java' then
              vim.cmd("silent bdelete! " .. current_buf)
            end
            M.post_decompile_setup(dest_file, class_dir)
          else
            print("JADX produced no output for " .. class_file)
          end
          vim.fn.delete(tmp_dir, "rf")
        end)
      end,
    }):start()
  else
    vim.cmd("silent edit " .. vim.fn.fnameescape(dest_file))
    M.post_decompile_setup(dest_file, class_dir)
  end
end

function M.restart_lsp_for_java()
  -- Find the jdtls client and restart it. This is more robust than a custom command.
  local clients = vim.lsp.get_active_clients({ bufnr = 0 })
  for _, client in ipairs(clients) do
    if client.name == "jdtls" then
      -- Use the official LSP restart. This is the most reliable way.
      vim.lsp.stop_client(client.id)
      vim.lsp.start_client({
        name = client.name,
        cmd = client.cmd,
        root_dir = client.root_dir,
        -- Copy over other necessary client settings if needed
      })
      print("Restarted jdtls.")
      return
    end
  end
  -- Fallback for other LSP setups
  if pcall(vim.cmd, "LspRestart jdtls") then
    print("LSP for jdtls restarted.")
  else
    print("Could not restart jdtls. You may need to do it manually.")
  end
end

--- Post-decompilation setup to configure the project environment.
function M.post_decompile_setup(java_file, class_dir)
  local tree_root = M.compute_tree_root(java_file, class_dir)
  M.ensure_project_files(tree_root)
  vim.b.java_decompile_tree_root = tree_root
  if vim.fn.getcwd() ~= tree_root then
    vim.cmd("cd " .. vim.fn.fnameescape(tree_root))
    M.restart_lsp_for_java()
  end
  M.resolve_deps(java_file, tree_root)
end

--- Extracts a .jar file and prepares the project.
function M.open_jar()
  local jar_file = vim.fn.expand("<afile>:p")
  local extract_dir = vim.fn.fnamemodify(jar_file, ":r")

  if vim.fn.isdirectory(extract_dir) == 0 then
    print("Extracting " .. vim.fn.fnamemodify(jar_file, ":t") .. "...")
    vim.fn.mkdir(extract_dir, "p")

    local command, args, cwd
    if vim.fn.executable("unzip") == 1 then
      command = "unzip"
      args = { "-q", "-o", jar_file, "-d", extract_dir }
      cwd = vim.fn.getcwd()
    else
      command = "jar"
      args = { "xf", jar_file }
      -- jar extracts to current dir, so we must cd
      cwd = extract_dir
    end

    Job:new({
      command = command,
      args = args,
      cwd = cwd,
      on_exit = function(j, return_val)
        if return_val ~= 0 then
          print("Failed to extract " .. jar_file)
          return
        end
        print("Extraction complete. Setting up project...")
        M.setup_jar_project(extract_dir)
      end,
    }):start()

  else
    print("Directory already exists. Setting up project...")
    M.setup_jar_project(extract_dir)
  end
  -- Prevent default buffer opening
  vim.cmd('setlocal bufhidden=wipe')
end

--- Sets up project files and resolves dependencies for an extracted jar.
function M.setup_jar_project(extract_dir)
  vim.schedule(function()
    M.ensure_project_files(extract_dir)
    vim.b.java_decompile_tree_root = extract_dir
    if vim.fn.getcwd() ~= extract_dir then
      vim.cmd("cd " .. vim.fn.fnameescape(extract_dir))
      M.restart_lsp_for_java()
    end

    -- APRI LA CARTELLA ESTRATTA (Questo mancava e causava il non-cambiamento visivo!)
    vim.cmd("silent! edit " .. vim.fn.fnameescape(extract_dir))

    local class_files = vim.fn.glob(extract_dir .. "/**/*.class", 0, 1)
    if #class_files > 0 then
      local sample_file = class_files[math.random(#class_files)]
      local java_file = vim.fn.fnamemodify(sample_file, ":r") .. ".java"
      if vim.fn.filereadable(java_file) == 0 then
        -- Decompile just one file to trigger dep resolution
        local tmp_dir = vim.fn.tempname()
        Job:new({
          command = "jadx",
          args = { "--no-res", "-d", tmp_dir, sample_file },
          on_exit = function()
              -- Schedule this part too
              vim.schedule(function()
                  local jf = vim.fn.glob(tmp_dir .. "/**/*.java", 0, 1)
                  if #jf > 0 then
                      vim.fn.writefile(vim.fn.readfile(jf[1]), java_file)
                      M.resolve_deps(java_file, extract_dir)
                  end
                  vim.fn.delete(tmp_dir, "rf")
              end)
          end
        }):start()
      else
        M.resolve_deps(java_file, extract_dir)
      end
    end
  end)
end

--- Resolves dependencies by calling the Python helper script.
-- @param java_file string: A sample java file from the project.
-- @param project_dir string: The root of the project.
function M.resolve_deps(java_file, project_dir)
  print("Resolving external dependencies...")
  Job:new({
    command = "uv",
    args = { "run", "python", resolve_script, java_file, project_dir },
    on_exit = function(j, return_val)
      vim.schedule(function()
        if return_val == 0 then
          print(".classpath updated with external dependencies.")
          M.restart_lsp_for_java() -- Restart LSP to pick up new classpath
        else
          print("Dependency resolution failed. Exit code: " .. tostring(return_val))
          local stderr = j:stderr_result()
          if stderr and #stderr > 0 then
            for _, line in ipairs(stderr) do
              print("ERR: " .. line)
            end
          end
        end
      end)
    end,
  }):start()
end


-- Setup autocommands
local augroup = vim.api.nvim_create_augroup("JavaDecompiler", { clear = true })
vim.api.nvim_create_autocmd("BufReadPost", {
  group = augroup,
  pattern = "*.class",
  callback = M.decompile_class,
})

vim.api.nvim_create_autocmd("BufReadCmd", {
  group = augroup,
  pattern = "*.jar",
  callback = function()
    -- Store CWD in case we use `jar` which needs a chdir
    vim.b.java_decompiler_cwd = vim.fn.getcwd()
    M.open_jar()
  end,
})

-- Placeholder for diagnostic logic
-- vim.api.nvim_create_autocmd("User", { pattern = "LspDiagnosticsChanged", ... })

    print("Java Decompiler module loaded.")
  end,
}
