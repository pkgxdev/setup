const { execSync } = require('child_process')
const fs = require('fs')
const os = require("os")

try {
  process.stdout.write("installing tea…\n")

  const GITHUB_TOKEN = process.env['INPUT_TOKEN'].trim()

  execSync(`${__dirname}/install.sh`, {
    stdio: "inherit",
    env: {
      ...process.env,
      GITHUB_TOKEN,
      YES: '1',
      FORCE: '1'
      //^^ so running this twice doesn’t do unexpected things
      //^^ NOTE ideally we would have a flag to just abort if already installed
    }
  })

  //TODO precise PATH to teafile
  const teafile = `${os.homedir()}/.tea/tea.xyz/v*/bin/tea`

  const GITHUB_PATH = process.env['GITHUB_PATH']
  fs.appendFileSync(GITHUB_PATH, `${teafile}\n`, {encoding: 'utf8'})

  const target = process.env['INPUT_TARGET']
  if (target) {
    execSync(`${teafile} ${target}`, {
      stdio: "inherit",
      env: { GITHUB_TOKEN }
    })
  }

  const out = execSync('/usr/local/bin/tea -Eds').toString()
  const match = out.match(/export VERSION=(.*)/)
  if (match && match[1]) {
    const version = match[1]
    process.stdout.write(`::set-output name=version::${version}\n`)

    const GITHUB_ENV = process.env['GITHUB_ENV']
    fs.appendFileSync(GITHUB_ENV, `VERSION=${version}\n`, {encoding: 'utf8'})
  }

} catch (err) {
  console.error(err)
  process.exitCode = 1
}
