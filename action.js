const { execSync } = require('child_process');
const semver = require('semver');
const https = require('https');
const path = require('path');
const tar = require('tar');
const fs = require('fs');
const os = require('os');

const dstdir = (() => {
  try {
    fs.accessSync('/usr/local/bin', fs.constants.W_OK);
    return '/usr/local/bin';
  } catch (err) {
    return path.join(process.env.INPUT_PKGX_DIR || path.join(os.homedir(), '.pkgx'), 'bin');
  }
})();

fs.writeFileSync(process.env["GITHUB_PATH"], `${dstdir}\n`);

function platform_key() {
  let platform = os.platform(); // 'darwin', 'linux', 'win32', etc.
  if (platform == 'win32') platform = 'windows';
  let arch = os.arch(); // 'x64', 'arm64', etc.
  if (arch == 'x64') arch = 'x86-64';
  if (arch == 'arm64') arch = 'aarch64';
  return `${platform}/${arch}`;
}

function downloadAndExtract(url, destination, strip) {
  return new Promise((resolve, reject) => {
    https.get(url, (response) => {
      if (response.statusCode !== 200) {
        reject(new Error(`Failed to get '${url}' (${response.statusCode})`));
        return;
      }

      console.log(`extracting tarball…`);

      const tar_stream = tar.x({ cwd: destination, strip });

      response
        .pipe(tar_stream) // Extract directly to destination
        .on('finish', resolve)
        .on('error', reject);

      tar_stream.on('error', reject);

    }).on('error', reject);
  });
}

function parse_pkgx_output(output) {

  const stripQuotes = (str) =>
    str.startsWith('"') || str.startsWith("'") ? str.slice(1, -1) : str;

  const replaceEnvVars = (str) => {
    const value = str
      .replaceAll(
        /\$\{([a-zA-Z0-9_]+):\+:\$[a-zA-Z0-9_]+\}/g,
        (_, key) => ((v) => v ? `:${v}` : "")(process.env[key]),
      )
      .replaceAll(/\$\{([a-zA-Z0-9_]+)\}/g, (_, key) => process.env[key] ?? "")
      .replaceAll(/\$([a-zA-Z0-9_]+)/g, (_, key) => process.env[key] ?? "");
    return value;
  };

  for (const line of output.split("\n")) {
    const match = line.match(/^([^=]+)=(.*)$/);
    if (match) {
      const [_, key, value_] = match;
      const value = stripQuotes(value_);
      if (key === "PATH") {
        value
          .replaceAll("${PATH:+:$PATH}", "")
          .replaceAll("$PATH", "")
          .replaceAll("${PATH}", "")
          .split(":").forEach((path) => {
            fs.appendFileSync(process.env["GITHUB_PATH"], `${path}\n`);
          });
      } else {
        let v = replaceEnvVars(value);
        fs.appendFileSync(process.env["GITHUB_ENV"], `${key}=${v}\n`);
      }
    }
  }
}

async function install_pkgx() {
  let strip = 3;

  async function get_url() {
    if (platform_key().startsWith('windows')) {
      // not yet versioned
      strip = 0;
      return 'https://pkgx.sh/Windows/x86_64.tgz';
    }

    let url = `https://dist.pkgx.dev/pkgx.sh/${platform_key()}/versions.txt`;

    console.log(`fetching ${url}`);

    const rsp = await fetch(url);
    const txt = await rsp.text();

    const versions = txt.split('\n');
    const version = process.env.INPUT_VERSION
      ? semver.maxSatisfying(versions, process.env.INPUT_VERSION)
      : versions.slice(-1)[0];

    if (!version) {
      throw new Error(`no version found for ${process.env.INPUT_VERSION}`);
    }

    console.log(`selected pkgx v${version}`);

    return `https://dist.pkgx.dev/pkgx.sh/${platform_key()}/v${version}.tar.gz`;
  }

  console.log(`::group::installing ${path.join(dstdir, 'pkgx')}`);

  const url = await get_url();

  console.log(`fetching ${url}`);

  if (!fs.existsSync(dstdir)) {
    fs.mkdirSync(dstdir, {recursive: true});
  }

  await downloadAndExtract(url, dstdir, strip);

  console.log(`::endgroup::`);
}

(async () => {
  await install_pkgx();

  if (process.env.INPUT_PKGX_DIR) {
    fs.appendFileSync(process.env["GITHUB_ENV"], `PKGX_DIR=${process.env.INPUT_PKGX_DIR}\n`);
  }

  if (os.platform() == 'linux') {
    console.log(`::group::installing pre-requisites`);
    const installer_script_path = path.join(path.dirname(__filename), "installer.sh");
    execSync(installer_script_path, {env: {PKGX_INSTALL_PREREQS: '1', ...process.env}});
    console.log(`::endgroup::`);
  }

  if (process.env['INPUT_+']) {
    console.log(`::group::installing pkgx input packages`);
    let args = process.env['INPUT_+'].split(' ');
    if (os.platform() == 'win32') {
      // cmd.exe uses ^ as an escape character
      args = args.map(x => x.replace('^', '^^'));
    }
    const cmd = `${path.join(dstdir, 'pkgx')} ${args.map(x => `+${x}`).join(' ')}`;
    console.log(`running: \`${cmd}\``);
    let env = undefined;
    if (process.env.INPUT_PKGX_DIR) {
      env = process.env
      env['PKGX_DIR'] = process.env.INPUT_PKGX_DIR;
    }
    const output = execSync(cmd, {env});
    parse_pkgx_output(output.toString());
    console.log(`::endgroup::`);
  }
})().catch(err => {
  console.error(`::error::${err.message}`)
  process.exit(1);
});
