const fs = require('fs');

const packagejson = require('./package.json');

packagejson.build.publish = [{
    url: "https://github.com/united-manufacturing-hub/UMHLens/releases/download/latest",
    provider: "generic"
}];

packagejson.build.win.artifactName = "UMHLens.Setup.${version}.exe";

fs.writeFileSync('package.json', JSON.stringify(packagejson));