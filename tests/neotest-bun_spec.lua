local async = require("nio").tests
require("busted")
local inspect = require("inspect")

local adapter = require("neotest-bun")

describe("neotest-bun", function()
	async.it("root", function()
		assert.Equal(adapter.root("."), nil)
	end)

	async.it("is_test_file", function()
		assert.False(adapter.is_test_file(""))
		assert.True(adapter.is_test_file("asdf.test.ts"))
		assert.False(adapter.is_test_file("asdf.testt.ts"))
	end)

	describe("discover_positions", function()
		local assert_test_positions_match = function(expected_output, positions)
			for i, value in ipairs(expected_output) do
				assert.is.truthy(value)
				local position = positions[i + 1][1]
				assert.is.truthy(position)
				assert.Equal(value.name, position.name)
				assert.Equal(value.type, position.type)
			end
		end

		async.it("provides meaningful names from a basic spec", function()
			local positions = adapter.discover_positions("./spec/basic.test.ts"):to_list()

			local expected_output = {
				{
					name = "basic.test.ts",
					type = "file",
				},
				{
					{
						name = "describe text",
						type = "namespace",
					},
					{
						name = "1",
						type = "test",
					},
					{
						name = "2",
						type = "test",
					},
					{
						name = "3",
						type = "test",
					},
					{
						name = "4",
						type = "test",
					},
				},
				{
					{
						name = "describe text 2",
						type = "namespace",
					},
					{
						name = "1",
						type = "test",
					},
					{
						name = "2",
						type = "test",
					},
					{
						name = "3",
						type = "test",
					},
					{
						name = "4",
						type = "test",
					},
				},
			}

			assert.Equal(expected_output[1].name, positions[1].name)
			assert.Equal(expected_output[1].type, positions[1].type)
			assert.Equal(expected_output[2][1].name, positions[2][1].name)
			assert.Equal(expected_output[2][1].type, positions[2][1].type)

			assert.Equal(5, #positions[2])
			for i, value in ipairs(expected_output[2][2]) do
				assert.is.truthy(value)
				local position = positions[2][i + 1][1]
				assert.is.truthy(position)
				assert.Equal(value.name, position.name)
				assert.Equal(value.type, position.type)
				assert.Equal(position.is_parameterized, false)
			end

			assert.Equal(expected_output[3][1].name, positions[3][1].name)
			assert.Equal(expected_output[3][1].type, positions[3][1].type)

			assert.Equal(5, #positions[2])
			assert_test_positions_match(expected_output[2][2], positions[2])

			assert.Equal(5, #positions[3])
			assert_test_positions_match(expected_output[3][2], positions[3])
		end)
	end)

	describe("Process result", function()
		async.it("works", function()
			local str = "inner &amp;gt; middle &amp;gt; outer"
			local splitted_str = str:split(" &amp;gt; ")
			assert.Equal(splitted_str[1], "inner")
			assert.Equal(splitted_str[2], "middle")
			assert.Equal(splitted_str[3], "outer")

			local inspect = require("inspect")
			local xml = [[
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="bun test" tests="2" assertions="1" failures="0" skipped="1" time="0.084069">
  <testsuite name="spec/nestedDescribe.test.ts" tests="2" assertions="1" failures="0" skipped="1" time="0" hostname="Bences-MacBook-Pro.local">
    <testcase name="should do a thing" classname="inner &amp;gt; middle &amp;gt; outer" time="0.000627" file="spec/nestedDescribe.test.ts" assertions="1" />
    <testcase name="this has a &apos;" classname="inner &amp;gt; middle &amp;gt; outer" time="0" file="spec/nestedDescribe.test.ts" assertions="0">
      <skipped />
    </testcase>
  </testsuite>
</testsuites>
			]]
			local result = require("neotest-bun.parse-result").xmlToNeotestResults(xml)
			assert.Equal(
				inspect({
					["spec/nestedDescribe.test.ts::outer::middle::inner::should do a thing"] = {
						status = "passed",
					},
				}),
				inspect(result)
			)
		end)

		async.it("works on example taken from a real project", function()
			local str = "inner &amp;gt; middle &amp;gt; outer"
			local splitted_str = str:split(" &amp;gt; ")
			assert.Equal(splitted_str[1], "inner")
			assert.Equal(splitted_str[2], "middle")
			assert.Equal(splitted_str[3], "outer")

			local xml = [[
<testsuites name="bun test" tests="1" assertions="2" failures="0" skipped="0" time="0.959527">
  <testsuite name="src/app/features/db.test.ts" tests="1" assertions="2" failures="0" skipped="0" time="0.006" hostname="Bences-MacBook-Pro.local">
    <testcase name="handles the test db properly, resets it between test runs, and allows interaction" classname="postgres" time="0.006859" file="src/app/features/db.test.ts" assertions="2" />
  </testsuite>
</testsuites>
			]]
			local result = require("neotest-bun.parse-result").xmlToNeotestResults(xml)
			assert.Equal(
				inspect({
					["src/app/features/db.test.ts::postgres::handles the test db properly, resets it between test runs, and allows interaction"] = {
						status = "passed",
					},
				}),
				inspect(result)
			)
		end)

		async.it("works on other example taken from a real project", function()
			local str = "inner &amp;gt; middle &amp;gt; outer"
			local splitted_str = str:split(" &amp;gt; ")
			assert.Equal(splitted_str[1], "inner")
			assert.Equal(splitted_str[2], "middle")
			assert.Equal(splitted_str[3], "outer")

			local xml = [[
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="bun test" tests="22" assertions="1" failures="0" skipped="21" time="0.843802">
  <testsuite name="src/app/modules/coupon/services/coupon/coupon-service-2.test.ts" tests="22" assertions="1" failures="0" skipped="21" time="0.016" hostname="Bences-MacBook-Pro.local">
    <testcase name="accepts coupon within valid date range" classname="Date validity &amp;gt; Validating coupon" time="0.016096" file="src/app/modules/coupon/services/coupon/coupon-service-2.test.ts" assertions="1" />
    <testcase name="rejects expired coupon" classname="Date validity &amp;gt; Validating coupon" time="0" file="src/app/modules/coupon/services/coupon/coupon-service-2.test.ts" assertions="0">
      <skipped />
    </testcase>
  </testsuite>
</testsuites>
			]]
			local result = require("neotest-bun.parse-result").xmlToNeotestResults(xml)
			assert.Equal(
				inspect({
					["src/app/modules/coupon/services/coupon/coupon-service-2.test.ts::Validating coupon::Date validity::accepts coupon within valid date range"] = {
						status = "passed",
					},
					["src/app/modules/coupon/services/coupon/coupon-service-2.test.ts::Validating coupon::Date validity::rejects expired coupon"] = {
						status = "skipped",
					},
				}),
				inspect(result)
			)
		end)

		async.it("handles nested testsuites without testcases", function()
			local xml = [[
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="bun test" tests="10" assertions="4" failures="0" skipped="9" time="1.571951">
  <testsuite name="src/app/modules/payment/services/payment/payment-jobs.test.ts" file="src/app/modules/payment/services/payment/payment-jobs.test.ts" tests="10" assertions="4" failures="0" skipped="9" time="0" hostname="Bences-MacBook-Pro.local">
    <testsuite name="payment jobs" file="src/app/modules/payment/services/payment/payment-jobs.test.ts" line="130" tests="10" assertions="4" failures="0" skipped="9" time="0.239" hostname="Bences-MacBook-Pro.local">
      <testcase name="processes multiple payment jobs concurrently" classname="payment jobs" time="0" file="src/app/modules/payment/services/payment/payment-jobs.test.ts" line="131" assertions="0">
        <skipped />
      </testcase>
      <testcase name="handles reservation balance payment" classname="payment jobs" time="0.239536" file="src/app/modules/payment/services/payment/payment-jobs.test.ts" line="350" assertions="4" />
    </testsuite>
  </testsuite>
</testsuites>
			]]
			local result = require("neotest-bun.parse-result").xmlToNeotestResults(xml)
			assert.Equal(
				inspect({
					["src/app/modules/payment/services/payment/payment-jobs.test.ts::payment jobs::processes multiple payment jobs concurrently"] = {
						status = "skipped",
					},
					["src/app/modules/payment/services/payment/payment-jobs.test.ts::payment jobs::handles reservation balance payment"] = {
						status = "passed",
					},
				}),
				inspect(result)
			)
		end)

		async.it("handles all passed tests in nested structure", function()
			local xml = [[
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="bun test" tests="3" assertions="28" failures="0" skipped="0" time="3.341727">
  <testsuite name="src/app/modules/payment/services/payment/cash-sync-2.test.ts" file="src/app/modules/payment/services/payment/cash-sync-2.test.ts" tests="3" assertions="28" failures="0" skipped="0" time="0" hostname="Bences-MacBook-Pro.local">
    <testsuite name="sync" file="src/app/modules/payment/services/payment/cash-sync-2.test.ts" line="11" tests="3" assertions="28" failures="0" skipped="0" time="1.065" hostname="Bences-MacBook-Pro.local">
      <testcase name="logged out payment" classname="sync" time="0.502228" file="src/app/modules/payment/services/payment/cash-sync-2.test.ts" line="12" assertions="9" />
      <testcase name="logged in payment" classname="sync" time="0.314535" file="src/app/modules/payment/services/payment/cash-sync-2.test.ts" line="81" assertions="13" />
      <testcase name="topup" classname="sync" time="0.249293" file="src/app/modules/payment/services/payment/cash-sync-2.test.ts" line="139" assertions="6" />
    </testsuite>
  </testsuite>
</testsuites>
			]]
			local result = require("neotest-bun.parse-result").xmlToNeotestResults(xml)
			assert.Equal(
				inspect({
					["src/app/modules/payment/services/payment/cash-sync-2.test.ts::sync::logged out payment"] = {
						status = "passed",
					},
					["src/app/modules/payment/services/payment/cash-sync-2.test.ts::sync::logged in payment"] = {
						status = "passed",
					},
					["src/app/modules/payment/services/payment/cash-sync-2.test.ts::sync::topup"] = {
						status = "passed",
					},
				}),
				inspect(result)
			)
		end)

		async.it("handles empty classname", function()
			local xml = [[
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="bun test" tests="3" assertions="9" failures="0" skipped="2" time="2.887823">
  <testsuite name="src/app/modules/payment/services/payment/cash-sync-2.test.ts" file="src/app/modules/payment/services/payment/cash-sync-2.test.ts" tests="3" assertions="9" failures="0" skipped="2" time="0.572" hostname="Bences-MacBook-Pro.local">
    <testcase name="logged out payment" classname="" time="0.572274" file="src/app/modules/payment/services/payment/cash-sync-2.test.ts" line="11" assertions="9" />
    <testcase name="logged in payment" classname="" time="0" file="src/app/modules/payment/services/payment/cash-sync-2.test.ts" line="80" assertions="0">
      <skipped />
    </testcase>
    <testcase name="topup" classname="" time="0" file="src/app/modules/payment/services/payment/cash-sync-2.test.ts" line="138" assertions="0">
      <skipped />
    </testcase>
  </testsuite>
</testsuites>
			]]
			local result = require("neotest-bun.parse-result").xmlToNeotestResults(xml)
			assert.Equal(
				inspect({
					["src/app/modules/payment/services/payment/cash-sync-2.test.ts::logged out payment"] = {
						status = "passed",
					},
				}),
				inspect(result)
			)
		end)
	end)
end)
