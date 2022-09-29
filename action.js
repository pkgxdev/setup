const { execSync, spawn } = require('child_process')
const fs = require('fs')
const os = require("os")
const https = require('https')

async function go() {
  process.stdout.write("installing tea…\n")

  const PREFIX = process.env['INPUT_PREFIX'] || `${os.homedir()}/opt`

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
      return `${process.platform}/x86-86`
    default:
      throw new Error(`unsupported platform: ${process.platform}/${process.arch}`)
    }
  })()

  console.log(`https://${process.env.TEA_SECRET}/tea.xyz/${midfix}/versions.txt`)

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

  process.stdout.write(`fetching tea.xyz@${v}\n`)

  fs.mkdirSync(PREFIX, { recursive: true })

  await new Promise((resolve, reject) => {
    https.get(`https://${process.env.TEA_SECRET}/tea.xyz/${midfix}/v${v}.tar.gz`, rsp => {
      if (rsp.statusCode != 200) return reject(rsp.statusCode)
      const tar = spawn('/usr/bin/tar', ['xf', '-'], { stdio: ['pipe', 'pipe', 'pipe'], cwd: PREFIX })
      rsp.pipe(tar.stdin)
      tar.on("end", resolve)
    }).on('error', reject)
  })

  const GITHUB_PATH = process.env['GITHUB_PATH']
  const bindir = `${PREFIX}/tea.xyz/v${v}/bin`
  fs.appendFileSync(GITHUB_PATH, `${bindir}\n`, {encoding: 'utf8'})

  const teafile = `${bindir}/tea`

  const target = process.env['INPUT_TARGET']
  if (target) {
    execSync(`${teafile} ${target}`, {stdio: "inherit"})
  }

  try {
    out = execSync(`${teafile} -Eds`).toString()
    const match = out.match(/export VERSION=(.*)/)
    if (match && match[1]) {
      const version = match[1]
      process.stdout.write(`::set-output name=version::${version}\n`)

      const GITHUB_ENV = process.env['GITHUB_ENV']
      fs.appendFileSync(GITHUB_ENV, `VERSION=${version}\n`, {encoding: 'utf8'})
    }
  } catch {
    // `tea -Eds` returns exit code 1 if no SRCROOT is found
    //TODO a flag so it returns 0 so we can not just swallow all errors lol
  }

  process.stdout.write(`::set-output name=prefix::${PREFIX}`)
}

go().catch(err => {
  console.error(err)
  process.exitCode = 1
})
