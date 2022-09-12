const { execSync } = require('child_process')
const fs = require('fs')
const os = require("os")

try {
  process.stdout.write("installing tea…\n")

  const PREFIX = process.env['INPUT_PREFIX'].trim() || `${os.homedir()}/opt`

  let out = execSync(`${__dirname}/install.sh`, {
    env: {
      ...process.env,
      PREFIX,
      YES: '1',
      FORCE: '1'
      //^^ so running this twice doesn’t do unexpected things
      //^^ NOTE ideally we would have a flag to just abort if already installed
    }
  }).toString()

  const v = out.trim().split("\n").slice(-1)[0].match(/\d+\.\d+\.\d+/)[0]
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

} catch (err) {
  console.error(err)
  process.exitCode = 1
}
