const { execSync, spawn } = require('child_process')
const https = require('https')
const path = require('path')
const fs = require('fs')
const os = require("os")

async function go() {
  process.stderr.write("determining latest tea version…\n")

  const PREFIX = process.env['INPUT_PREFIX'] || `${os.homedir()}/opt`
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

  const v = await new Promise((resolve, reject) => {
    https.get(`https://${process.env.TEA_SECRET}/tea.xyz/${midfix}/versions.txt`, rsp => {
      if (rsp.statusCode != 200) return reject(rsp.statusCode)
      rsp.setEncoding('utf8')
      const chunks = []
      rsp.on("data", x => chunks.push(x))
      rsp.on("end", () => {
        resolve(chunks.join("").split("\n").at(-1))
      })
    }).on('error', reject)
  })

  process.stderr.write(`fetching tea.xyz@${v}\n`)

  fs.mkdirSync(PREFIX, { recursive: true })

  const exitcode = await new Promise((resolve, reject) => {
    https.get(`https://${process.env.TEA_SECRET}/tea.xyz/${midfix}/v${v}.tar.gz`, rsp => {
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

  const target = process.env['INPUT_TARGET']
  if (target) {
    execSync(`${teafile} ${target}`, {stdio: "inherit", env})
  }

  try {
    const GITHUB_ENV = process.env['GITHUB_ENV']

    out = execSync(`${teafile} -Eds`, {env}).toString()
    const match = out.match(/export VERSION=['"]?(\d+\.\d+\.\d+)/)
    if (match && match[1]) {
      const version = match[1]
      process.stdout.write(`::set-output name=version::${version}\n`)
      fs.appendFileSync(GITHUB_ENV, `VERSION=${version}\n`, {encoding: 'utf8'})
    }

    if (TEA_DIR) {
      process.stdout.write(`::set-output name=srcroot::${TEA_DIR}\n`)
      fs.appendFileSync(GITHUB_ENV, `TEA_DIR=${TEA_DIR}\n`, {encoding: 'utf8'})
    }
  } catch {
    // `tea -Eds` returns exit code 1 if no SRCROOT is found
    //TODO a flag so it returns 0 so we can not just swallow all errors lol
  }

  process.stdout.write(`::set-output name=prefix::${PREFIX}`)

  process.stderr.write(`installed ${PREFIX}/tea.xyz/v${v}\n`)
}

go().catch(err => {
  console.error(err)
  process.exitCode = 1
})
