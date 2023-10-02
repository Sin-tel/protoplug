exclude_files = { "**/lib/*.lua" }

std = "max+protoplug"
stds.protoplug = {
   globals = { "polyGen", "stereoFx", "processMidi", "plugin" },
   read_globals = {},
}

ignore = {
   "212", -- unused function arg
   "213", -- unused loop variable
   "561", -- cyclomatic complexity
}

-- allow_defined_top = true
