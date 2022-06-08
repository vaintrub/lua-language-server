package.path = package.path .. ';script/?.lua;tools/?.lua'

local fs       = require 'bee.filesystem'
local config   = require 'configuration'
local markdown = require 'provider.markdown'
local util     = require 'utility'
local lloader  = require 'locale-loader'
local inspect  = require 'inspect'
local json     = require 'json'

local function getLocale()
    local locale = {}

    for dirPath in fs.pairs(fs.path 'locale') do
        local lang = dirPath:filename():string()
        local text = util.loadFile((dirPath / 'setting.lua'):string())
        if text then
            locale[lang] = lloader(text, lang)
        end
    end

    return locale
end

local localeMap = getLocale()

local function getDesc(lang, desc)
    if not desc then
        return nil
    end
    if desc:sub(1, 1) ~= '%' or desc:sub(-1, -1) ~= '%' then
        return desc
    end
    local locale = localeMap[lang]
    if not locale then
        return desc
    end
    local id = desc:sub(2, -2)
    return locale[id]
end

local function buildType(md, lang, conf)
    md:add('md', '## type')
    if type(conf.type) == 'table' then
        md:add('md', ('`%s | %s`'):format(conf.type[1], conf.type[2]))
    elseif conf.type == 'array' then
        md:add('md', ('`%s<%s>`'):format(conf.type, conf.items.type))
    else
        md:add('md', ('`%s`'):format(conf.type))
    end
    md:emptyLine()
end

local function buildDesc(md, lang, conf)
    local desc = conf.markdownDescription or conf.description
    desc = getDesc(lang, desc)
    if desc then
        md:add('md', desc)
    else
        md:add('md', '**Missing description!!**')
    end
    md:emptyLine()
end

local function buildDefault(md, lang, conf)
    if not conf.default then
        return
    end
    local default = conf.default
    if default == json.null then
        default = nil
    end
    md:add('md', '## default')
    md:emptyLine()
    if type(default) == 'table' and conf.type == 'array' then
        md:add('md', ('`[%s]`'):format(inspect(default):sub(2, -2)))
    else
        md:add('md', ('`%s`'):format(inspect(default)))
    end
    md:emptyLine()
end

local function buildEnum(md, lang, conf)
    if not conf.enum then
        return nil
    end
    md:add('md', '## enum')
    md:emptyLine()
    for i, enum in ipairs(conf.enum) do
        local desc = getDesc(lang, conf.markdownEnumDescriptions and conf.markdownEnumDescriptions[i])
        if desc then
            md:add('md', ('* `%s`: %s'):format(inspect(enum), desc))
        else
            md:add('md', ('* `%s`'):format(inspect(enum)))
        end
    end
end

local function buildMarkdown(lang)
    local dir = fs.path 'doc' / lang / 'config'
    fs.create_directories(dir)
    local configDoc = markdown()

    for name, conf in util.sortPairs(config) do
        configDoc:add('md', '# ' .. name:gsub('^Lua%.', ''))
        configDoc:emptyLine()
        buildDesc(configDoc, lang, conf)
        buildType(configDoc, lang, conf)
        buildDefault(configDoc, lang, conf)
        buildEnum(configDoc, lang, conf)
        configDoc:emptyLine()
    end

    util.saveFile((dir / 'config.md'):string(), configDoc:string())
end

for lang in pairs(localeMap) do
    buildMarkdown(lang)
end