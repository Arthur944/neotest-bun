require("neotest.types")
local lib = require("neotest.lib")
local parser = require("neotest-bun.parse-result")

---@class neotest-bun.Config
---@field ignore_react_native_jest boolean Disable adapter for React Native projects with Jest config (default: false)
local config = {
	ignore_react_native_jest = false,
}

local function readXMLFile(file_path)
	local file, err = io.open(file_path, "r")
	if not file then
		error("Failed to open file: " .. (err or "unknown error"))
		return nil
	end

	local content = file:read("*all")
	file:close()

	return content
end

--- Check if a file exists
---@param path string
---@return boolean
local function file_exists(path)
	local file = io.open(path, "r")
	if file then
		file:close()
		return true
	end
	return false
end

--- Check if the project has a Jest config file
---@param root_dir string
---@return boolean
local function has_jest_config(root_dir)
	local jest_config_files = {
		"jest.config.js",
		"jest.config.ts",
		"jest.config.mjs",
		"jest.config.cjs",
		"jest.config.json",
	}

	for _, config_file in ipairs(jest_config_files) do
		if file_exists(root_dir .. "/" .. config_file) then
			return true
		end
	end

	return false
end

--- Check if the project has react-native as a dependency
---@param root_dir string
---@return boolean
local function has_react_native(root_dir)
	local package_json_path = root_dir .. "/package.json"
	local file = io.open(package_json_path, "r")
	if not file then
		return false
	end

	local content = file:read("*all")
	file:close()

	-- Simple pattern matching for react-native in dependencies
	-- This checks for "react-native" as a key in the JSON
	if content:match('"react%-native"%s*:') then
		return true
	end

	return false
end

--- Check if the adapter should be disabled for this project
--- Returns true if ignore_react_native_jest is enabled and both Jest config and react-native are detected
---@param root_dir string
---@return boolean
local function should_disable_adapter(root_dir)
	if not config.ignore_react_native_jest then
		return false
	end
	return has_jest_config(root_dir) and has_react_native(root_dir)
end

---@class neotest.Adapter
Adapter = {
	name = "neotest-bun",

	---Find the project root directory given a current directory to work from.
	---Should no root be found, the adapter can still be used in a non-project context if a test file matches.
	---@async
	---@param dir string @Directory to treat as cwd
	---@return string | nil @Absolute root dir of test suite
	root = function(dir)
		local root_dir = lib.files.match_root_pattern("package.json")(dir)
		if root_dir and should_disable_adapter(root_dir) then
			return nil
		end
		return root_dir
	end,

	---Filter directories when searching for test files
	---@async
	---@param name string Name of directory
	---@param rel_path string Path to directory, relative to root
	---@param root string Root directory of project
	---@return boolean
	filter_dir = function(name, rel_path, root)
		return name ~= "node_modules"
	end,

	---@async
	---@param file_path string
	---@return boolean
	is_test_file = function(file_path)
		if file_path == nil then
			return false
		end
		local is_test_file = false

		for _, pattern in ipairs({
			"%.test%.ts$",
			"%.test%.tsx$",
			"%.spec%.ts$",
			"%.spec%.tsx$",
			"%.test%.js$",
			"%.test%.jsx$",
			"%.spec%.js$",
			"%.spec%.jsx$",
		}) do
			local match_result = string.match(file_path, pattern)
			if match_result then
				is_test_file = true
				break
			end
		end

		return is_test_file
	end,

	---Given a file path, parse all the tests within it.
	---@async
	---@param file_path string Absolute file path
	---@return neotest.Tree | nil
	discover_positions = function(file_path)
		local query = [[
    ; -- Namespaces --
    ; Matches: `describe('context', () => {})`
    ((call_expression
      function: (identifier) @func_name (#eq? @func_name "describe")
      arguments: (arguments (string (string_fragment) @namespace.name) (arrow_function))
    )) @namespace.definition
    ; Matches: `describe('context', function() {})`
    ((call_expression
      function: (identifier) @func_name (#eq? @func_name "describe")
      arguments: (arguments (string (string_fragment) @namespace.name) (function_expression))
    )) @namespace.definition
    ; Matches: `describe.only('context', () => {})`
    ((call_expression
      function: (member_expression
        object: (identifier) @func_name (#any-of? @func_name "describe")
      )
      arguments: (arguments (string (string_fragment) @namespace.name) (arrow_function))
    )) @namespace.definition
    ; Matches: `describe.only('context', function() {})`
    ((call_expression
      function: (member_expression
        object: (identifier) @func_name (#any-of? @func_name "describe")
      )
      arguments: (arguments (string (string_fragment) @namespace.name) (function_expression))
    )) @namespace.definition
    ; Matches: `describe.each(['data'])('context', () => {})`
    ((call_expression
      function: (call_expression
        function: (member_expression
          object: (identifier) @func_name (#any-of? @func_name "describe")
        )
      )
      arguments: (arguments (string (string_fragment) @namespace.name) (arrow_function))
    )) @namespace.definition
    ; Matches: `describe.each(['data'])('context', function() {})`
    ((call_expression
      function: (call_expression
        function: (member_expression
          object: (identifier) @func_name (#any-of? @func_name "describe")
        )
      )
      arguments: (arguments (string (string_fragment) @namespace.name) (function_expression))
    )) @namespace.definition

    ; -- Tests --
    ; Matches: `test('test') / it('test')`
    ((call_expression
      function: (identifier) @func_name (#any-of? @func_name "it" "test")
      arguments: (arguments (string (string_fragment) @test.name) [(arrow_function) (function_expression)])
    )) @test.definition
    ; Matches: `test.only('test') / it.only('test')`
    ((call_expression
      function: (member_expression
        object: (identifier) @func_name (#any-of? @func_name "test" "it")
      )
      arguments: (arguments (string (string_fragment) @test.name) [(arrow_function) (function_expression)])
    )) @test.definition
    ; Matches: `test.each(['data'])('test') / it.each(['data'])('test')`
    ((call_expression
      function: (call_expression
        function: (member_expression
          object: (identifier) @func_name (#any-of? @func_name "it" "test")
          property: (property_identifier) @each_property (#eq? @each_property "each")
        )
      )
      arguments: (arguments (string (string_fragment) @test.name) [(arrow_function) (function_expression)])
    )) @test.definition
		]]

		local positions = lib.treesitter.parse_positions(file_path, query, {
			nested_tests = true,
			build_position = 'require("neotest-bun").build_position',
		})

		return positions
	end,

	---@param args neotest.RunArgs
	---@return nil | neotest.RunSpec | neotest.RunSpec[]
	build_spec = function(args)
		local position = args.tree:data()
		local command = { "bun", "test", "--reporter=junit", "--reporter-outfile=./neotest-bun.xml" }

		-- Add test name pattern if running a specific test
		if position.type == "test" then
			table.insert(command, "--test-name-pattern")
			table.insert(command, position.name)
		end

		-- Add file path if running a specific file
		if position.path then
			table.insert(command, position.path)
		end

		return {
			command = command,
			context = {
				file = position.path,
				pos_id = position.id,
			},
		}
	end,

	---@async
	---@param spec neotest.RunSpec
	---@param _result neotest.StrategyResult
	---@param tree neotest.Tree
	---@return table<string, neotest.Result>
	results = function(spec, _result, tree)
		local xml_content = readXMLFile("./neotest-bun.xml")
		os.remove("./neotest-bun.xml")
		local results = parser.xmlToNeotestResults(xml_content)

		local formatted_results = {}

		for key, result in pairs(results) do
			-- Check if key already contains a full path, if not prepend cwd
			local formatted_key
			if string.match(key, "^/") then
				-- Key already has absolute path
				formatted_key = key
			else
				-- Key needs full path - prepend cwd
				formatted_key = vim.fn.getcwd() .. "/" .. key
			end
			formatted_results[formatted_key] = result
		end

		local inspect = vim and vim.inspect or require("inspect")

		-- Debug: Write XML content and parsed results to files for debugging
		local debug_file_xml = io.open("./neotest-bun-debug-xml.txt", "w")
		if debug_file_xml and false then
			debug_file_xml:write("=== SPEC ===\n")
			debug_file_xml:write(inspect(spec))
			debug_file_xml:write("\n\n=== _RESULT ===\n")
			debug_file_xml:write(inspect(_result))
			debug_file_xml:write("\n\n=== TREE ===\n")
			debug_file_xml:write(inspect(tree))
			debug_file_xml:write("\n\n=== XML CONTENT ===\n")
			debug_file_xml:write(xml_content)
			debug_file_xml:write("\n\n=== RAW PARSED RESULTS ===\n")
			debug_file_xml:write(inspect(results))
			debug_file_xml:write("\n\n=== FORMATTED RESULTS ===\n")
			debug_file_xml:write(inspect(formatted_results))
			debug_file_xml:close()
		end

		return formatted_results
	end,
}

local function get_match_type(captured_nodes)
	if captured_nodes["test.name"] then
		return "test"
	end
	if captured_nodes["namespace.name"] then
		return "namespace"
	end
end

function Adapter.build_position(file_path, source, captured_nodes)
	local match_type = get_match_type(captured_nodes)
	if not match_type then
		return
	end

	---@type string
	local name = vim.treesitter.get_node_text(captured_nodes[match_type .. ".name"], source)
	local definition = captured_nodes[match_type .. ".definition"]

	return {
		type = match_type,
		path = file_path,
		name = name,
		range = { definition:range() },
	}
end

---@param opts neotest-bun.Config|nil
function Adapter.setup(opts)
	opts = opts or {}
	if opts.ignore_react_native_jest ~= nil then
		config.ignore_react_native_jest = opts.ignore_react_native_jest
	end
	return Adapter
end

setmetatable(Adapter, {
	---@param opts neotest-bun.Config|nil
	__call = function(_, opts)
		return Adapter.setup(opts)
	end,
})

return Adapter
