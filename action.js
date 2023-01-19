const { execSync, spawn } = require('child_process')
const https = require('https')
const path = require('path')
const fs = require('fs')
const os = require("os")

async function go() {
  process.stderr.write("determining latest tea version…\n")

  const HOMEDIR = process.env['GITHUB_WORKSPACE'] || os.homedir()

  const PREFIX = process.env['INPUT_PREFIX'] || `${HOMEDIR}/opt`
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

  // install packages
  execSync(`${teafile} --sync --env --keep-going echo`, {env})

  // get env FIXME one call should do init
  out = execSync(`${teafile} --sync --env --keep-going --dry-run`, {env}).toString()

  console.error(out)

  const lines = out.split("\n")
  console.error(lines.length)

  for (const line of lines) {
    console.error(line)
    if (!line.startsWith("export ")) continue
    const parts = line.split("=");
    const key = parts[0].split(" ")[1];
    const value = parts[1].slice(0, -1);
    if (key == 'VERSION') {
      fs.appendFileSync(GITHUB_OUTPUT, `version=${version}\n`, {encoding: 'utf8'})
    }
    fs.appendFileSync(GITHUB_ENV, `${key}=${value}\n`, {encoding: 'utf8'})
    console.error(key, value)
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

  const target = process.env['INPUT_TARGET']
  if (target) {
    execSync(`${teafile} ${target}`, {stdio: "inherit", env})
  }

  fs.appendFileSync(GITHUB_OUTPUT, `prefix=${PREFIX}\n`, {encoding: 'utf8'})
  process.stderr.write(`installed ${PREFIX}/tea.xyz/v${v}\n`)
}

go().catch(err => {
  console.error(err)
  process.exitCode = 1
})
