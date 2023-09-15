import { porcelain, hooks, Path, utils, PackageRequirement } from "@teaxyz/lib"
import { exec } from "@actions/exec"
import * as core from '@actions/core'
import * as path from 'path'
import * as os from "os"

const { useConfig, useShellEnv } = hooks
const { install } = porcelain
const { flatmap } = utils

async function go() {
  const TEA_DIR = core.getInput('TEA_DIR') as string

  let vtea = core.getInput('version') ?? ""
  if (vtea && !/^[*^~@=]/.test(vtea)) {
    vtea = `@${vtea}`
  }

  const pkgs = [`tea.xyz${vtea}`]
  for (let key in process.env) {
    if (key.startsWith("INPUT_+")) {
      const value = process.env[key]!
      if (key == 'INPUT_+') {
        for (const item of value.split(/\s+/)) {
          if (item.trim()) {
            pkgs.push(item)
      }}} else {
        key = key.slice(7).toLowerCase()
        pkgs.push(key+value)
  }}}

  core.info(`fetching ${pkgs.join(", ")}…`)

  const prefix = flatmap(TEA_DIR, (x: string) => new Path(x)) ?? Path.home().join(".tea")

  useConfig({
    prefix,
    cache: prefix.join(".cache"),
    pantries: [],
    UserAgent: 'tea.setup/0.1.0', //TODO version
    options: { compression: 'gz' }
  })
  const { map, flatten } = useShellEnv()

  await hooks.useSync()

  const pkgrqs = await Promise.all(pkgs.map(parse))
  const installations = await install(pkgrqs)
  const env = flatten(await map({ installations }))

  for (const [key, value] of Object.entries(env)) {
    if (key == 'PATH') {
      core.addPath(value)
    } else {
      core.exportVariable(key, value)
    }
  }

  if (TEA_DIR) {
    core.exportVariable('TEA_DIR', TEA_DIR)
  }

  if (os.platform() != 'darwin') {
    // use our installer to install any required pre-requisites from the system packager
    const installer_script = path.join(path.dirname(__filename), "installer.sh")
    if (process.getuid && process.getuid() == 0) {
      await exec(installer_script)
    } else {
      await exec('sudo', [installer_script])
    }
  }

  core.info(`installed ${installations.map(({pkg}) => utils.pkg.str(pkg)).join(', ')}`)
}

go().catch(core.setFailed)


async function parse(input: string): Promise<PackageRequirement> {
  const find = hooks.usePantry().find
  const rawpkg = utils.pkg.parse(input)

  const projects = await find(rawpkg.project)
  if (projects.length <= 0) throw new Error(`not found ${rawpkg.project}`)
  if (projects.length > 1) throw new Error(`ambiguous project ${rawpkg.project}`)

  const project = projects[0].project //FIXME libtea forgets to correctly assign type
  const constraint = rawpkg.constraint

  return { project, constraint }
}
