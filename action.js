const { execSync } = require('child_process')
const fs = require('fs')
const os = require("os")

try {
  process.stdout.write("installing tea…\n")

  const GITHUB_TOKEN = process.env['INPUT_TOKEN'].trim()
  const PREFIX = process.env['INPUT_PREFIX'].trim() || '/opt'

  let out = execSync(`${__dirname}/install.sh`, {
    stdio: "inherit",
    env: {
      ...process.env,
      GITHUB_TOKEN,
      PREFIX,
      YES: '1',
      FORCE: '1'
      //^^ so running this twice doesn’t do unexpected things
      //^^ NOTE ideally we would have a flag to just abort if already installed
    }
  })

  const v = out.split("\n").slice(-1).match(/\d+\.\d+\.\d+/)[0]
  const GITHUB_PATH = process.env['GITHUB_PATH']
  const bindir = `${PREFIX}/tea.xyz/v${v}/bin`
  fs.appendFileSync(GITHUB_PATH, `${bindir}}\n`, {encoding: 'utf8'})

  //TODO precise PATH to teafile
  const teafile = `${bindir}/tea`

  const target = process.env['INPUT_TARGET']
  if (target) {
    execSync(`${teafile} ${target}`, {
      stdio: "inherit",
      env: { GITHUB_TOKEN }
    })
  }

  out = execSync(`${teafile} -Eds`).toString()
  const match = out.match(/export VERSION=(.*)/)
  if (match && match[1]) {
    const version = match[1]
    process.stdout.write(`::set-output name=version::${version}\n`)

    const GITHUB_ENV = process.env['GITHUB_ENV']
    fs.appendFileSync(GITHUB_ENV, `VERSION=${version}\n`, {encoding: 'utf8'})
  }

  process.stdout.write(`::set-output name=prefix::${PREFIX}`)

} catch (err) {
  console.error(err)
  process.exitCode = 1
}
