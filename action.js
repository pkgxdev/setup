const { plumbing, hooks, Path, utils, semver, SemVer } = require("@teaxyz/lib")
const { getExecOutput, exec } = require("@actions/exec")
const { install, link, resolve, hydrate } = plumbing
const { useConfig, useSync, useCellar } = hooks
const core = require('@actions/core')
const path = require('path')
const os = require("os")

async function go() {
  const TEA_PREFIX = core.getInput('prefix') || `${os.homedir()}/.tea`

  const TEA_DIR = (() => {
    let TEA_DIR = core.getInput('srcroot').trim()
    if (!TEA_DIR) return
    if (!TEA_DIR.startsWith("/")) {
      // for security this must be an absolute path
      TEA_DIR = `${process.cwd()}/${TEA_DIR}`
    }
    return path.normalize(TEA_DIR)
  })()

  let vtea = core.getInput('version') ?? ""
  if (vtea && !/^[*^~@=]/.test(vtea)) {
    vtea = `@${vtea}`
  }

  const pkgs = [`tea.xyz${vtea}`]
  for (let key in process.env) {
    if (key.startsWith("INPUT_+")) {
      const value = process.env[key]
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
  if (TEA_PREFIX == '/opt' && os.platform == 'darwin') {
    await exec('sudo', ['chown', `${os.userInfo().username}:staff`, '/opt'])
  }

  core.info(`fetching ${pkgs.join(", ")}…`)

  useConfig({
    prefix: new Path(TEA_PREFIX),
    pantries: [],
    cache: new Path(TEA_PREFIX).join('tea.xyz/var/www'),
    UserAgent: 'tea.setup/0.1.0', //TODO version
    options: { compression: 'gz' }
  })
  await useSync()
  const { pkgs: tree } = await hydrate(pkgs.map(utils.pkg.parse))
  const { pending } = await resolve(tree)
  for (const pkg of pending) {
    core.info(`installing ${utils.pkg.str(pkg)}`)
    const installation = await install(pkg)
    await link(installation)
  }

  const tea = await useCellar().resolve({project: 'tea.xyz', constraint: new semver.Range('*')})
  const teafile = tea.path.join('bin/tea').string
  const env_args = []

  if (TEA_DIR && tea.pkg.version.gte(new SemVer("0.19"))) {
    env_args.push('--env', '--keep-going')
  } else if (TEA_DIR) {
    env_args.push('--env')
  }

  let args = tea.pkg.version.gte(new SemVer("0.21"))
    ? []
    : tea.pkg.version.gte(new SemVer("0.19"))
      ? ["--dry-run"]
      : ["--dump"]

  if (core.getBooleanInput("chaste")) {
    args.push('--chaste')
  }

  //FIXME we’re running tea/cli since dev-envs are not in libtea
  // and we don’t want them in libtea, but we may need a libteacli as a result lol
  const { stdout: out } = await getExecOutput(
    teafile,
    [...env_args, ...args, ...pkgs.map(x=>`+${x}`)],
    {env: { ...process.env, TEA_DIR, TEA_PREFIX }})

  const lines = out.split("\n")
  for (const line of lines) {
    const match = line.match(/(export )?([A-Za-z0-9_]+)=['"]?(.*)/)
    if (!match) continue
    const [,,key,value] = match
    if (key == 'PATH') {
      for (const part of value.split(":").reverse()) {
        core.addPath(part)
      }
    } else {
      core.exportVariable(key, value)
      if (key == 'VERSION') {
        core.setOutput('version', value)
      }
    }
  }

  if (TEA_DIR) {
    core.setOutput('srcroot', TEA_DIR)
    core.exportVariable('TEA_DIR', TEA_DIR)
  }

  if (os.platform() != 'darwin') {
    const sh = path.join(path.dirname(__filename), "install-pre-reqs.sh")
    if (process.getuid() == 0) {
      await exec(sh)
    } else {
      await exec('sudo', [sh])
    }
  }

  //TODO deprecated exe/md
  //NOTE BUT LEAVE BECAUSE WE ONCE SUPPORTED THIS
  const target = core.getInput('target')
  if (target) {
    await exec(teafile, [target], { env: { ...process.env, TEA_DIR, TEA_PREFIX } })
  }

  core.exportVariable('TEA_PREFIX', TEA_PREFIX)
  core.setOutput('prefix', TEA_PREFIX)

  core.info(`installed ${tea.path}`)
}

go().catch(core.setFailed)
