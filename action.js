import { spawnSync } from 'child_process'

spawnSync("./install.sh", [], {stdio: "inherit"})
