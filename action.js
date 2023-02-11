const { execSync, spawn } = require('child_process')
const https = require('https')
const path = require('path')
const fs = require('fs')
const os = require("os")

async function go() {
  process.stderr.write("determining latest tea version…\n")

  const PREFIX = process.env['INPUT_PREFIX'] || `${os.homedir()}/.tea`
  const TEA_DIR = (() => {
    let TEA_DIR = process.env['INPUT_SRCROOT']
    if (!TEA_DIR) return
    TEA_DIR = TEA_DIR.trim()
    if (!TEA_DIR) return
    if (!TEA_DIR.startsWith("/")) {
      // for security this must be an absolute path
      TEA_DIR = `${process.cwd()}/${TEA_DIR}`
    }
    return path.normalize(TEA_DIR)
  })()

  const additional_pkgs = []
  for (let key in process.env) {
    if (key.startsWith("INPUT_+")) {
      const value = process.env[key]
      if (key == 'INPUT_+') {
        for (const item of value.split(/\s+/)) {
          if (item.trim()) {
            additional_pkgs.push(`+${item}`)
      }}} else {
        key = key.slice(6).toLowerCase()
        additional_pkgs.push(key+value)
  }}}

  // we build to /opt and special case this action so people new to
  // building aren’t immediatelyt flumoxed
  if (PREFIX == '/opt' && os.platform == 'darwin') {
    execSync('sudo chown $(whoami):staff /opt')
  }

  const midfix = (() => {
    switch (process.arch) {
    case 'arm64':
      return `${process.platform}/aarch64`
    case 'x64':
      return `${process.platform}/x86-64`
    default:
      throw new Error(`unsupported platform: ${process.platform}/${process.arch}`)
    }
  })()

  const v = process.env['INPUT_VERSION'] || await new Promise((resolve, reject) => {
    https.get(`https://dist.tea.xyz/tea.xyz/${midfix}/versions.txt`, rsp => {
      if (rsp.statusCode != 200) return reject(rsp.statusCode)
      rsp.setEncoding('utf8')
      const chunks = []
      rsp.on("data", x => chunks.push(x))
      rsp.on("end", () => {
        resolve(chunks.join("").trim().split("\n").at(-1))
      })
    }).on('error', reject)
  })

  process.stderr.write(`fetching tea.xyz@${v}\n`)

  fs.mkdirSync(PREFIX, { recursive: true })

  const exitcode = await new Promise((resolve, reject) => {
    https.get(`https://dist.tea.xyz/tea.xyz/${midfix}/v${v}.tar.gz`, rsp => {
      if (rsp.statusCode != 200) return reject(rsp.statusCode)
      const tar = spawn('tar', ['xzf', '-'], { stdio: ['pipe', 'inherit', 'inherit'], cwd: PREFIX })
      rsp.pipe(tar.stdin)
      tar.on("close", resolve)
    }).on('error', reject)
  })

  if (exitcode != 0) {
    throw new Error(`tar: ${exitcode}`)
  }

  const oldwd = process.cwd()
  process.chdir(`${PREFIX}/tea.xyz`)
  if (fs.existsSync(`v*`)) fs.unlinkSync(`v*`)
  fs.symlinkSync(`v${v}`, `v*`, 'dir')
  if (fs.existsSync(`v0`)) fs.unlinkSync(`v0`)
  fs.symlinkSync(`v${v}`, `v0`, 'dir') //FIXME
  process.chdir(oldwd)

  const GITHUB_PATH = process.env['GITHUB_PATH']
  const bindir = `${PREFIX}/tea.xyz/v${v}/bin`
  fs.appendFileSync(GITHUB_PATH, `${bindir}\n`, {encoding: 'utf8'})

  const teafile = `${bindir}/tea`

  const env = {
    TEA_DIR,
    ...process.env
  }

  const GITHUB_ENV = process.env['GITHUB_ENV']
  const GITHUB_OUTPUT = process.env['GITHUB_OUTPUT']

  const vv = parseFloat(v)
  const env_flag = TEA_DIR ? vv >= 0.19 ? '--env --keep-going' : '--env' : ''

  // get env FIXME one call should do init

  let args = vv >= 0.21
    ? ""
    : vv >= 0.19
      ? "--dry-run"
      : "--dump"

  if (process.env["INPUT_CHASTE"] == "true") {
    args += " --chaste"
  }

  out = execSync(`${teafile} --sync ${env_flag} ${args} ${additional_pkgs.join(" ")}`, {env}).toString()

  const lines = out.split("\n")
  for (const line of lines) {
    const match = line.match(/(export )?([A-Za-z0-9_]+)=['"]?(.*)/)
    if (!match) continue
    const [,,key,value] = match
    if (key == 'VERSION') {
      fs.appendFileSync(GITHUB_OUTPUT, `version=${value}\n`, {encoding: 'utf8'})
    }
    if (key == 'PATH') {
      for (const part of value.split(":").reverse()) {
        fs.appendFileSync(GITHUB_PATH, `${part}\n`, {encoding: 'utf8'})
      }
    } else {
      fs.appendFileSync(GITHUB_ENV, `${key}=${value}\n`, {encoding: 'utf8'})
    }
  }

  if (TEA_DIR) {
    fs.appendFileSync(GITHUB_OUTPUT, `srcroot=${TEA_DIR}\n`, {encoding: 'utf8'})
    fs.appendFileSync(GITHUB_ENV, `TEA_DIR=${TEA_DIR}\n`, {encoding: 'utf8'})
  }

  if (os.platform() != 'darwin') {
    const sh = path.join(path.dirname(__filename), "install-pre-reqs.sh")
    if (process.getuid() == 0) {
      execSync(sh)
    } else {
      execSync(`sudo ${sh}`)
    }
  }

  //TODO deprecated exe/md
  //NOTE BUT LEAVE BECAUSE WE ONCE SUPPORTED THIS
  const target = process.env['INPUT_TARGET']
  if (target) {
    execSync(`${teafile} ${target}`, {stdio: "inherit", env})
  }

  fs.appendFileSync(GITHUB_ENV, `TEA_PREFIX=${PREFIX}\n`, {encoding: 'utf8'})
  fs.appendFileSync(GITHUB_OUTPUT, `prefix=${PREFIX}\n`, {encoding: 'utf8'})

  process.stderr.write(`installed ${PREFIX}/tea.xyz/v${v}\n`)
}

go().catch(err => {
  console.error(err)
  process.exitCode = 1
})
