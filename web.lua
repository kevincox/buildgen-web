-- Copyright 2011 Kevin Cox

--[[---------------------------------------------------------------------------]
[                                                                              ]
[  Permission is hereby granted, free of charge, to any person obtaining a     ]
[  copy of this software and associated documentation files (the "Software"),  ]
[  to deal in the Software without restriction, including without limitation   ]
[  the rights to use, copy, modify, merge, publish, distribute, sublicense,    ]
[  and/or sell copies of the Software, and to permit persons to whom the       ]
[  Software is furnished to do so, subject to the following conditions:        ]
[                                                                              ]
[  The above copyright notice and this permission notice shall be included in  ]
[  all copies or substantial portions of the Software.                         ]
[                                                                              ]
[  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR  ]
[  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,    ]
[  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL     ]
[  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER  ]
[  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING     ]
[  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER         ]
[  DEALINGS IN THE SOFTWARE.                                                   ]
[                                                                              ]
[-----------------------------------------------------------------------------]]

S.import "stdlib"

L.web = {}

if not P.L.web then P.L.web = {} end

do -- So that we can hide our locals.
local state = {}

local optimizationLevel = "normal"

function validOptimizationLevels ( level )
	T.utils.assert_string(1, level)

	return T.Set{"min", "normal", "max"}[level]
end

function L.web.setMinificationLevel ( level )
	T.utils.assert_arg(1, level, "string", valid, "invalid optomization level.")

	optimizationLevel = level
end

local jsminis = T.Map{
	["closure"] = {
		exe = "closure", -- Name of the executable
		compile = {},
		input = {"--js", "%s"},
		output = {"--js_output_file", "%s"},
		level = {
			min    = "--compilation_level=WHITESPACE_ONLY",
			normal = "--compilation_level=SIMPLE_OPTIMIZATIONS",
			max    = "--compilation_level=ADVANCED_OPTIMIZATIONS",
		},
	},
	["yui"] = {
		exe = "yuicompressor", -- Name of the executable
		compile = "--type=js",
		input = "%s",
		output = {"-o", "%s"},
		level = {
			min    = "--disable-optimizations",
			normal = {},
			max    = {},
		},
	},
}

--- Check to see if a JavaScript Minifier is available.
--
-- Checks to see that a minifier is available and that L.web knows how
-- to use it.
--
-- @param name The name of the compiler (often the name of the executable).
-- @returns ``true`` if the compiler can be used otherwise ``false``.
function L.web.hasJSMinifier ( name )
	T.utils.assert_string(1, name)

	if jsminis[name] == nil then return false end

	local m = jsminis[name]
	if not S.findExecutable(m.exe) then return false end

	return true
end

--- Select which compiler to use.
--
-- This function selects the C++ compiler to use.  You should first check if
-- the compiler is avaiable with ``S.cpp.hasCompiler()``.
--
-- @param name The name of the compiler (often the name of the executable).
function L.web.useJSMinifier ( name )
	T.utils.assert_arg(1, name, "string",
	                  L.web.hasCompiler, "Unknown minifier",
	                  2)

	local m = jsminis[name]

	local function makeList ( path )
		local m = m; -- The parent table.
		local i;     -- The index in c.
		for e in path:split("."):iter() do -- Recursively get table.
			if i then m = m[i] end
			i = e
		end

		if type(m[i]) == "table" then
			m[i] = T.List(m[i])
		else
			m[i] = T.List{m[i]}
		end

		return m[i]
	end

	m.exe = S.findExecutable(m.exe)

	makeList "compile"
	makeList "input"
	makeList "output"
	makeList "level.min"
	makeList "level.normal"
	makeList "level.max"

	P.L.web.jsmini = m
end

function findJsMinifier ( )
	if P.L.web.jsmini then return P.L.web.jsmini end

	for m in jsminis:iter() do         -- Find the a compiler that they have
		if L.web.hasJSMinifier(m) then -- installed on thier system.
			L.web.useJSMinifier(m)
			break
		end
	end

	if not P.L.web.jsmini then
		error("Error: No JavaScript minifier/compiler found.", 0)
	end

	return P.L.web.jsmini
end

function L.web.minifyJS ( files, out,  options )
	if type(files) ~= "table" then files = {files} end
	files = T.List(files):map(C.path)
	out   = C.path(out)

	local m = findJsMinifier()

	local a = T.List{m.exe}
	a:extend(m.compile)
	a:extend(m.level[optimizationLevel])

	a:extend(m.output:map():format(out))
	files:foreach(function(p) a:extend(m.input:map():format(p)) end)

	C.addGenerator(files, a, {out}, {
		description = "Compressing "..out
	})
end

end
