---@class Attr
---@field assertions string
---@field failures string
---@field name string
---@field skipped? string
---@field tests string
---@field time string
---@field hostname? string
---@field classname? string
---@field file? string

---@class Skipped
-- Empty class representing a skipped test

---@class Failure
---@field _attr { type: string }

---@class Error

---@class TestCase
---@field _attr Attr
---@field skipped? Skipped
---@field error? Error
---@field failure? Failure

---@class TestSuite
---@field _attr Attr
---@field testcase TestCase[] Array of test cases

---@class TestSuites
---@field _attr Attr
---@field testsuite TestSuite

---@class RootObject
---@field testsuites TestSuites[]

function string:split(delimiter)
	local result = {}
	local from = 1
	local delim_from, delim_to = string.find(self, delimiter, from)

	while delim_from do
		table.insert(result, string.sub(self, from, delim_from - 1))
		from = delim_to + 1
		delim_from, delim_to = string.find(self, delimiter, from)
	end

	table.insert(result, string.sub(self, from))
	return result
end

function ReverseAndJoin(str)
	-- Split the string by " &;gt; "
	local parts = str:split(" &gt; ")
	-- Reverse the array
	local reversed = {}
	for i = #parts, 1, -1 do
		table.insert(reversed, parts[i])
	end

	-- Join with "::"
	return table.concat(reversed, "::")
end

local function xmlToNeotestResults(xml_string)
	local xml2lua = require("xml2lua")
	local handler = require("xmlhandler.tree"):new()
	local parser = xml2lua.parser(handler)
	local inspect = require("inspect")
	parser:parse(xml_string)

	---@type RootObject
	local root = handler.root
	local results = {}

	local testsuites = #root.testsuites == 0 and { root.testsuites } or root.testsuites

	-- Process test suites
	for _, testsuite in ipairs(testsuites) do
		local suites = #testsuite.testsuite == 0 and { testsuite.testsuite } or testsuite.testsuite
		for _, suite in ipairs(suites) do
			local file_path = suite._attr.name
			local testcases = #suite.testcase == 0 and { suite.testcase } or suite.testcase

			-- Process test cases
			for _, testcase in ipairs(testcases) do
				local test_name = testcase._attr.name
				local classname = testcase._attr.classname

				-- Check for failures or errors within the test case
				local status = "passed"
				local errors = {}

				if testcase.failure or testcase.error then
					status = "failed"
					table.insert(errors, {
						message = testcase.failure._attr.type or "",
					})
				end
				if testcase.skipped then
					status = "skipped"
				end

				-- Create neotest result structure
				local result = {
					status = status,
					-- short = string.format("%s::%s (%s)", classname, test_name, status),
					errors = #errors > 0 and errors or nil,
				}

				-- Generate a unique ID for this test
				local id = file_path .. "::" .. ReverseAndJoin(classname) .. "::" .. test_name
				results[id] = result
			end
		end
	end

	return results
end

return {
	xmlToNeotestResults = xmlToNeotestResults,
}
