const { execSync } = require('child_process')
const fs = require('fs')

try {
  process.stdout.write("Installing tea…\n")

  const GITHUB_TOKEN = process.env['INPUT_TOKEN'].trim()
  execSync(`${__dirname}/install.sh`, {} , {
    stdio: "inherit",
    env: { GITHUB_TOKEN }
  })

  const target = process.env['INPUT_TARGET']
  if (target) {
    execSync(`/usr/local/bin/tea ${target}`, {
      stdio: "inherit",
      env: { GITHUB_TOKEN }
    })
  }

  const out = execSync('/usr/local/bin/tea -Eds').toString()
  const match = out.match(/export VERSION=(.*)/)
  if (match && match[1]) {
    const version = match[1]
    process.stdout.write(`::set-output name=version::${version}\n`)

    const path = process.env['GITHUB_ENV']
    fs.appendFileSync(path, `VERSION=${version}\n`, {encoding: 'utf8'})
  }

} catch (err) {
  console.error(err)
  process.exitCode = 1
}
