const { execSync } = require('child_process')

try {
  console.info("Installing tea…")
  execSync(`${__dirname}/install.sh`, [], {stdio: "inherit"})
} catch (err) {
  console.error(err)
}
