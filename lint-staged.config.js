module.exports = {
  'sfdx-project.json': () => {
    return `npm run package:version:number:sync`;
  },
  '*.{cls,cmp,component,css,html,js,json,md,page,trigger,yaml,yml}': filenames => filenames.map(filename => `prettier --write '${filename}'`),
  '*.{cls,trigger}': () => {
    return [`npm run scan:apex`];
  }
};
