local fs = require("@lune/fs")
local process = require("@lune/process")
local stdio = require("@lune/stdio")
local task = require("@lune/task")

type ChildProcess = process.ChildProcess
type ChildProcessReader = process.ChildProcessReader
type ChildProcessStatus = { ok: boolean, code: number }

local PROJECT_NAME = "default"
local PROJECT_FILE = `{PROJECT_NAME}.project.json`
local PACKAGE_DIRECTORIES = { "Packages", "ServerPackages" }

local function pipe(child: ChildProcess): ChildProcessStatus
	local function readStream(stream: ChildProcessReader, output: (string) -> ())
		return task.spawn(function()
			while true do
				local chunk = stream:read()
				if not chunk then
					break
				end

				output(chunk)
			end
		end)
	end

	readStream(child.stdout, stdio.write)
	readStream(child.stderr, stdio.write)

	return child:status()
end

local function exec(cmdline: string)
	local pieces = {}
	for piece in string.gmatch(" " .. cmdline, "%s+([^%s]+)") do
		table.insert(pieces, piece)
	end

	local program = table.remove(pieces, 1)
	assert(program ~= nil, "cmdline must include a program")

	local child = process.create(program, pieces)
	local status = pipe(child)

	if not status.ok then
		process.exit(status.code)
	end
end

exec("wally install")
exec(`rojo sourcemap -o {PROJECT_NAME}.sourcemap.json ./{PROJECT_FILE}`)

for _, packageDir in PACKAGE_DIRECTORIES do
	if fs.isDir(`./{packageDir}`) then
		exec(`wally-package-types --sourcemap {PROJECT_NAME}.sourcemap.json ./{packageDir}/`)
	else
		stdio.write(
			`{stdio.color("yellow")}WARNING: Package directory "{packageDir}" does not exist!{stdio.color("reset")}\n`
		)
	end
end
