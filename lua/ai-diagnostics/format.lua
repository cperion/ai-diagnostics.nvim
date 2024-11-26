local log = require("ai-diagnostics.log")
local utils = require("ai-diagnostics.utils")
local grouping = require("ai-diagnostics.grouping")
local M = {}

---Convert a value to number or return nil if not possible
---@param value any The value to convert
---@return number|nil
local function to_number(value)
    log.debug("Converting to number: " .. vim.inspect(value) .. " (type: " .. type(value) .. ")")
    if type(value) == "number" then
        log.debug("Already a number: " .. tostring(value))
        return value
    elseif type(value) == "string" then
        local num = tonumber(value)
        log.debug("Converted string to number: " .. tostring(num))
        return num
    end
    log.debug("Failed to convert to number")
    return nil
end

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
			local line_number = to_number(line.number)
			if not line_number then
				log.warn("Invalid line number found: " .. tostring(line.number))
				goto continue
			end

			if diagnostic.range then
				log.debug("Processing diagnostic range: " .. vim.inspect(diagnostic.range))
				-- Ensure all range values are numbers
				if type(diagnostic.range.start) == "table" then
					log.debug("Processing range.start: " .. vim.inspect(diagnostic.range.start))
					diagnostic.range.start.line = to_number(diagnostic.range.start.line) or 0
					diagnostic.range.start.character = to_number(diagnostic.range.start.character) or 0
					log.debug("Converted range.start - line: " .. tostring(diagnostic.range.start.line) .. 
						", character: " .. tostring(diagnostic.range.start.character))
				else
					log.debug("range.start is not a table, creating default")
					diagnostic.range.start = { line = 0, character = 0 }
				end
				
				if type(diagnostic.range['end']) == "table" then
					log.debug("Processing range.end: " .. vim.inspect(diagnostic.range['end']))
					diagnostic.range['end'].line = to_number(diagnostic.range['end'].line) or diagnostic.range.start.line
					diagnostic.range['end'].character = to_number(diagnostic.range['end'].character) or 0
					log.debug("Converted range.end - line: " .. tostring(diagnostic.range['end'].line) .. 
						", character: " .. tostring(diagnostic.range['end'].character))
				else
					log.debug("range.end is not a table, creating default")
					diagnostic.range['end'] = {
						line = diagnostic.range.start.line,
						character = 0
					}
				end
			end

			if not line_map[line_number] then
				line_map[line_number] = {
					content = line.content,
					diagnostics = {},
					is_context = true,
				}
			end

			-- Check if this is the diagnostic's line
			if line_number == (diagnostic.lnum or 0) + 1 then
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
	log.debug("Diagnostic data: " .. vim.inspect(diagnostics))

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
				local formatted_line = line_content

				-- Add diagnostics if present
				if #line.diagnostics > 0 then
					local diag_messages = {}
					for _, diag in ipairs(line.diagnostics) do
						table.insert(diag_messages, format_inline_diagnostic(diag))
					end
						
					-- Add padding between code and diagnostics
					local padding = math.max(40 - #line_content, 2)
					formatted_line = formatted_line .. string.rep(" ", padding) .. table.concat(diag_messages, "  ")
				end

				-- Add line numbers if configured
				if require("ai-diagnostics").config.show_line_numbers then
					formatted_line = string.format("%4d: %s", line.number, formatted_line)
				end

				-- Always add the line to output
				table.insert(output, formatted_line)
			end
			-- Add a blank line between blocks
			table.insert(output, "")
		end
	end

	local formatted_output = table.concat(output, "\n")
	log.debug(string.format("Formatted output length: %d", #formatted_output))
	return formatted_output
end

return M
