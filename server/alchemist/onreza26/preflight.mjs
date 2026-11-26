// Local read-only presence check. Never searches files, Drive, chat or Git for keys.
import {spawnSync} from 'node:child_process';
const tokenPresent=Boolean(process.env.NRZ_TOKEN);
const cli=spawnSync('nrz',['--version'],{encoding:'utf8',timeout:10000});
const cliAvailable=!cli.error&&cli.status===0;
console.log(JSON.stringify({tokenPresent,cliAvailable,status:!tokenPresent?'BLOCKED_OWNER':!cliAvailable?'BLOCKED_ENV':'READY_FOR_READ_ONLY_INVENTORY',createdResources:0}));
if(!tokenPresent||!cliAvailable)process.exitCode=2;
// Even READY does not create resources: inventory, actual pricing, explicit budget,
// and workspace identity are independent gates. No speculative API endpoints.
