local log = require("ai-diagnostics.log")
local utils = require("ai-diagnostics.utils")
local grouping = require("ai-diagnostics.grouping")
local M = {}

---Group diagnostics by line and merge overlapping contexts
---@param diagnostics table[] Array of diagnostics
---@param contexts table[] Array of context information for each diagnostic
---@return table[] Array of merged context blocks
local function merge_contexts(diagnostics, contexts)
	-- Create a map of line numbers to their content and diagnostics
	local line_map = {}

	for i, context_lines in ipairs(contexts) do
		local diagnostic = diagnostics[i]
		for _, line in ipairs(context_lines) do
			-- Convert line number to number type if it's a string
			local line_number = tonumber(line.number)
			if not line_number then
				log.warn("Invalid line number found: " .. tostring(line.number))
				goto continue
			end
			
			if not line_map[line_number] then
				line_map[line_number] = {
					content = line.content,
					diagnostics = {},
					is_context = true,
				}
			end
			
			-- Check if this is the actual diagnostic line from the LSP
			-- Use the diagnostic's range information instead of line.is_diagnostic
			if diagnostic.range and line_number == diagnostic.range.start.line + 1 then
				table.insert(line_map[line_number].diagnostics, diagnostic)
			end
			
			::continue::
		end
	end

	-- Convert map to sorted array
	local merged = {}
	local line_numbers = vim.tbl_keys(line_map)
	table.sort(line_numbers)

	-- Group continuous lines
	local current_group = nil
	for _, lnum in ipairs(line_numbers) do
		local line = line_map[lnum]
		if not current_group or lnum > current_group.end_line + 1 then
			if current_group then
				table.insert(merged, current_group)
			end
			current_group = {
				start_line = lnum,
				end_line = lnum,
				lines = {},
			}
		end
		current_group.end_line = lnum
		table.insert(current_group.lines, {
			number = lnum,
			content = line.content,
			diagnostics = line.diagnostics,
		})
	end
	if current_group then
		table.insert(merged, current_group)
	end

	return merged
end

---Format a diagnostic message inline
---@param diagnostic table The diagnostic to format
---@return string Formatted diagnostic message
local function format_inline_diagnostic(diagnostic)
	return string.format("[%s: %s]", 
		utils.severity_to_string(diagnostic.severity), 
		diagnostic.message:gsub("^%s+", ""):gsub("%s+$", "")  -- Trim whitespace
	)
end

---Format diagnostics with merged context, grouped by file
---@param diagnostics table[] Array of diagnostics
---@param contexts table[] Array of context lines with line numbers and markers
---@param filenames string[] Array of filenames corresponding to each diagnostic
---@return string Formatted diagnostic output
---@throws "Mismatched array lengths" when input arrays have different lengths
function M.format_diagnostic_with_context(diagnostics, contexts, filenames)
	log.debug(string.format("Formatting %d diagnostics", #diagnostics))

	if #diagnostics == 0 then
		log.debug("No diagnostics to format")
		return ""
	end

	local file_groups = grouping.group_by_file(diagnostics, contexts, filenames)
	log.debug(string.format("Grouped into %d files", #vim.tbl_keys(file_groups)))

	local output = {}
	log.debug(string.format("Grouped into %d files", #vim.tbl_keys(file_groups)))

	-- Sort filenames for consistent output
	local sorted_files = vim.tbl_keys(file_groups)
	table.sort(sorted_files)

	for _, filename in ipairs(sorted_files) do
		local group = file_groups[filename]
		-- Add filename header
		local display_filename = filename
		if require("ai-diagnostics").config.sanitize_filenames then
			display_filename = utils.sanitize_filename(filename)
		end
		table.insert(
			output,
			string.format("\n" .. require("ai-diagnostics").config.file_header_format, display_filename)
		)

		-- Format merged context for this file's diagnostics
		local merged = merge_contexts(group.diagnostics, group.contexts)

		for _, block in ipairs(merged) do
			for _, line in ipairs(block.lines) do
				local line_content = utils.truncate_string(line.content)
				if #line.diagnostics > 0 then
					local diag_messages = {}
					for _, diag in ipairs(line.diagnostics) do
						local formatted_diag = format_inline_diagnostic(diag)
						for diag_line in formatted_diag:gmatch("[^\r\n]+") do
							table.insert(diag_messages, diag_line)
						end
					end
					line_content = line_content .. string.rep(" ", math.max(40 - #line_content, 2)) .. table.concat(diag_messages, "  ")
				end

				local show_line_numbers = require("ai-diagnostics").config.show_line_numbers
				local formatted_line = show_line_numbers
					and string.format("%4d: %s", tonumber(line.number) or 0, line_content)
					or line_content

				if #line.diagnostics > 0 then
					table.insert(output, formatted_line)
				else
					table.insert(output, line_content)
				end
			end
		end
	end

	local formatted_output = table.concat(output, "\n")
	log.debug(string.format("Formatted output length: %d", #formatted_output))
	return formatted_output
end

return M
