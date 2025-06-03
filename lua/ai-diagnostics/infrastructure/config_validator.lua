---@class ConfigValidator
local ConfigValidator = {}

---Validate configuration
---@param cfg table Configuration to validate
---@return boolean valid
---@return string|nil error_message
function ConfigValidator.validate(cfg)
    -- Type checks
    if cfg.before_lines and type(cfg.before_lines) ~= "number" then
        return false, "before_lines must be a number"
    end
    if cfg.after_lines and type(cfg.after_lines) ~= "number" then
        return false, "after_lines must be a number"
    end
    if cfg.max_line_length and type(cfg.max_line_length) ~= "number" then
        return false, "max_line_length must be a number"
    end
    if cfg.show_line_numbers ~= nil and type(cfg.show_line_numbers) ~= "boolean" then
        return false, "show_line_numbers must be a boolean"
    end
    
    -- Semantic validation
    if cfg.before_lines and cfg.before_lines < 0 then
        return false, "before_lines must be non-negative"
    end
    if cfg.after_lines and cfg.after_lines < 0 then
        return false, "after_lines must be non-negative"
    end
    if cfg.max_line_length and cfg.max_line_length < 10 then
        return false, "max_line_length must be at least 10"
    end
    
    -- Severity validation
    if cfg.severity ~= nil then
        if type(cfg.severity) ~= "number" then
            return false, "severity must be a number"
        end
        if cfg.severity < 1 or cfg.severity > 4 then
            return false, "severity must be between 1 (ERROR) and 4 (HINT)"
        end
    end
    
    -- Log configuration validation
    if cfg.log then
        if type(cfg.log) ~= "table" then
            return false, "log must be a table"
        end
        if cfg.log.enabled ~= nil and type(cfg.log.enabled) ~= "boolean" then
            return false, "log.enabled must be a boolean"
        end
        if cfg.log.level and type(cfg.log.level) ~= "string" then
            return false, "log.level must be a string"
        end
        if cfg.log.level and not vim.tbl_contains({"DEBUG", "INFO", "WARN", "ERROR"}, cfg.log.level) then
            return false, "log.level must be one of: DEBUG, INFO, WARN, ERROR"
        end
        if cfg.log.file and type(cfg.log.file) ~= "string" then
            return false, "log.file must be a string"
        end
        if cfg.log.max_size and type(cfg.log.max_size) ~= "number" then
            return false, "log.max_size must be a number"
        end
    end
    
    -- Format string validation
    if cfg.file_header_format and type(cfg.file_header_format) ~= "string" then
        return false, "file_header_format must be a string"
    end
    if cfg.line_number_format and type(cfg.line_number_format) ~= "string" then
        return false, "line_number_format must be a string"
    end
    
    return true
end

return ConfigValidator
