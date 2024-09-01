const fs = require('fs');

/**
 * @returns {string}
 */
function readRemapping() {
    return fs.readFileSync('./remappings.txt', 'utf8');
}

/**
 * @returns {object}
 */
function readVscodeSettings() {
    return JSON.parse(fs.readFileSync('./.vscode/settings.json', 'utf8'));
}

function main() {
    const remapping = readRemapping().split('\n').filter(el => el !== '').map((el) => `${__dirname}/${el}`);
    console.log(remapping);
    const vscodeSettings = readVscodeSettings();

    vscodeSettings["solidity.remappings"] = remapping;
    console.log(vscodeSettings);
    fs.writeFileSync('./.vscode/settings.json', JSON.stringify(vscodeSettings, null, 4));
}

main();