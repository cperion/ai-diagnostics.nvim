local Diagnostic = require("ai-diagnostics.models.diagnostic")
local FileDiagnostics = require("ai-diagnostics.models.file_diagnostics")
local DiagnosticContext = require("ai-diagnostics.models.diagnostic_context")
local Result = require("ai-diagnostics.utils").Result

---@class DiagnosticService
---@field config table Configuration
---@field logger Logger Logger instance
local DiagnosticService = {}
DiagnosticService.__index = DiagnosticService

---Create a new DiagnosticService instance
---@param config table Configuration
---@param logger Logger Logger instance
---@return DiagnosticService
function DiagnosticService:new(config, logger)
	return setmetatable({
		config = config,
		logger = logger,
	}, self)
end

---Get diagnostics for a single buffer
---@param bufnr number Buffer number
---@return Result Result<FileDiagnostics>
function DiagnosticService:get_buffer_diagnostics(bufnr)
	-- Validate buffer
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return Result:err("Invalid buffer: " .. tostring(bufnr))
	end

	if not vim.api.nvim_buf_is_loaded(bufnr) then
		return Result:err("Buffer not loaded: " .. tostring(bufnr))
	end

	local bufname = vim.api.nvim_buf_get_name(bufnr)
	if bufname == "" then
		return Result:err("Buffer has no file name")
	end

	-- Check for LSP clients (optional - we still show diagnostics without LSP)
	local clients = vim.lsp.get_clients({ bufnr = bufnr })
	if #clients == 0 then
		self.logger:debug("No LSP clients for buffer " .. tostring(bufnr))
	end

	-- Get diagnostics
	local vim_diagnostics = vim.diagnostic.get(bufnr, {
		severity = self.config.severity,
	})

	if #vim_diagnostics == 0 then
		return Result:ok(FileDiagnostics:new(bufname, {}))
	end

	-- Convert to our data model
	local diagnostics = {}
	for _, vim_diag in ipairs(vim_diagnostics) do
		local context_result = DiagnosticContext:from_buffer(
			bufnr,
			vim_diag.lnum,
			vim_diag.end_lnum or vim_diag.lnum,
			self.config.before_lines,
			self.config.after_lines
		)

		local context = context_result.is_ok and context_result.value or nil
		local diagnostic = Diagnostic:new(vim_diag, context)
		table.insert(diagnostics, diagnostic)
	end

	local relative_path = vim.fn.fnamemodify(bufname, ":.")
	return Result:ok(FileDiagnostics:new(relative_path, diagnostics))
end

---Get diagnostics for all workspace buffers
---@return Result Result<table<string, FileDiagnostics>>
function DiagnosticService:get_workspace_diagnostics()
	local results = {}

	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		local result = self:get_buffer_diagnostics(bufnr)
		if result.is_ok and #result.value.diagnostics > 0 then
			results[result.value.filename] = result.value
		end
	end

	if vim.tbl_isempty(results) then
		return Result:err("No diagnostics found in workspace")
	end

	return Result:ok(results)
end

return DiagnosticService
