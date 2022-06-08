const { execSync } = require('child_process')

try {
  console.info("Installing tea…")
  const GITHUB_TOKEN = process.env['INPUT_TOKEN'].trim()
  execSync(`${__dirname}/install.sh`, [], {
    stdio: "inherit",
    env: { GITHUB_TOKEN }
  })
} catch (err) {
  console.error(err)
}
