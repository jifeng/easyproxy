if (require.extensions['.coffee']) {
  module.exports = require('./lib/proxy.coffee');
} else {
  module.exports = require('./out/release/lib/proxy.js');
}
