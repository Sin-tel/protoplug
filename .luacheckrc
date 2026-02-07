exclude_files = { "**/lib/*.lua" }

std = "max+protoplug"
stds.protoplug = {
   globals = { "polyGen", "stereoFx", "processMidi", "plugin", "params" },
   read_globals = { "ffi", "midi", "juce" },
}

ignore = {
   "212", -- unused function arg
   "213", -- unused loop variable
   "561", -- cyclomatic complexity
   "631", -- line too long
}

-- allow_defined_top = true
