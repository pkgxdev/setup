const { execSync, spawn } = require('child_process')
const fs = require('fs')
const os = require("os")

async function go() {
  process.stdout.write("installing tea…\n")

  const PREFIX = process.env['INPUT_PREFIX'].trim() || `${os.homedir()}/opt`

  // we build to /opt and special case this action so people new to
  // building aren’t immediatelyt flumoxed
  if (PREFIX == '/opt' && os.platform == 'darwin') {
    execSync('sudo chown $(whoami):staff /opt')
  }

  let rsp = await fetch(`https://${process.env.TEA_SECRET}/tea.xyz/${midfix}/versions.txt`)
  const v = (await rsp.text()).split("\n").at(-1)

  rsp = await fetch(`https://${process.env.TEA_SECRET}/tea.xyz/${midfix}/v${V}.tar.gz`)

  const tar = spawn('tar', ['xf', '-'], { stdio: [ 0, 'pipe', 'pipe' ], cwd: PREFIX })
  await rsp.body().pipe(tar.stdin.createWriteStream())

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
