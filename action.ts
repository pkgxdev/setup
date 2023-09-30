import { porcelain, hooks, Path, utils, PackageRequirement } from "libpkgx"
import { exec } from "@actions/exec"
import * as core from '@actions/core'
import * as path from 'path'
import * as os from "os"

const { useConfig, useShellEnv } = hooks
const { install } = porcelain
const { flatmap } = utils

async function go() {
  const PKGX_DIR = core.getInput('PKGX_DIR') || core.getInput('TEA_DIR')

  let vpkgx = core.getInput('version') ?? ""
  if (vpkgx && !/^[*^~@=]/.test(vpkgx)) {
    vpkgx = `@${vpkgx}`
  }

  const pkgs = [`pkgx.sh${vpkgx}`]
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


  // we build to /opt and special case this action so people new to
  // building aren’t immediately flumoxed
  if (PKGX_DIR == '/opt' && os.platform() == 'darwin') {
    await exec('sudo', ['chown', `${os.userInfo().username}:staff`, '/opt'])
  }

  core.info(`fetching ${pkgs.join(", ")}…`)

  const prefix = flatmap(PKGX_DIR, (x: string) => new Path(x)) ?? Path.home().join(".pkgx")

  useConfig({
    prefix,
    data: prefix.join(".data"),
    cache: prefix.join(".cache"),
    pantries: [],
    UserAgent: 'pkgx.setup/0.1.0', //TODO version
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

  if (PKGX_DIR) {
    core.exportVariable('PKGX_DIR', PKGX_DIR)
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

  const project = projects[0].project //FIXME libpkgx forgets to correctly assign type
  const constraint = rawpkg.constraint

  return { project, constraint }
}
