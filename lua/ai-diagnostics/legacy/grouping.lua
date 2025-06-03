local M = {}

---Group diagnostics and contexts by filename
---@param diagnostics table[] Array of diagnostics
---@param contexts table[] Array of context lines
---@param filenames string[] Array of filenames
---@return table Grouped diagnostics by file
---@throws "Mismatched array lengths" when input arrays have different lengths
function M.group_by_file(diagnostics, contexts, filenames)
	if #diagnostics ~= #contexts or #diagnostics ~= #filenames then
		vim.notify("Mismatched array lengths in diagnostic grouping", vim.log.levels.ERROR)
		return {}
	end

	local file_groups = {}

	for i, diagnostic in ipairs(diagnostics) do
		local filename = filenames[i]
		if not file_groups[filename] then
			file_groups[filename] = {
				diagnostics = {},
				contexts = {},
			}
		end
		table.insert(file_groups[filename].diagnostics, diagnostic)
		table.insert(file_groups[filename].contexts, contexts[i])
	end

	return file_groups
end


return M
