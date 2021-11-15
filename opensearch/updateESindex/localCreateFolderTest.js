
// Mock event
const event = require('./localCreateFolderTestEvent')

// Mock environment variables
process.env.AWS_REGION = 'us-west-2';
process.env.language = 'en';
process.env.domain = 'os-endpoint.graymeta.com';
process.env.region = 'us-west-2';

// Lambda handler
const { handler } = require('./index')

const main = async () => {
  console.time('localCreateTest')
  await handler(event)
  console.timeEnd('localCreateTest')
}

main().catch(error => console.error(error))